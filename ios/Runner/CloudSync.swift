import BackgroundTasks
import CloudKit
import Flutter
import UIKit
import os

/// iCloud sync for Momentum Plus (docs/design/sync.md). The Dart side does
/// all the merging; this only keeps "buckets" (JSON, each owned by one
/// device) in the person's private CloudKit database, through
/// `CKSyncEngine`, which batches, retries, works offline and fetches when
/// another device changes something.
///
/// Nothing here runs until Dart asks (sync is off by default): people who
/// never turn it on never touch CloudKit. Buckets waiting to go (the outbox)
/// and fetched ones Dart hasn't taken yet (the inbox) are kept in files, so
/// a background fetch with no Flutter running loses nothing. The folder is
/// left out of backups: a phone restored from one starts fresh, fetches
/// everything, and Dart sees it's a copy of another device.
final class CloudSync: NSObject, CKSyncEngineDelegate, @unchecked Sendable {
  static let shared = CloudSync()

  static let containerID = "iCloud.com.paulblake.momentum"
  static let zoneID = CKRecordZone.ID(zoneName: "Momentum", ownerName: CKCurrentUserDefaultName)
  static let recordType = "Bucket"
  static let schema = 1

  /// Whether this build was signed with iCloud (`MomentumICloud` in
  /// Info.plist, NO for free-team builds): CloudKit crashes an app without
  /// the entitlement, so nothing touches it then.
  static var isAvailableInBuild: Bool {
    (Bundle.main.object(forInfoDictionaryKey: "MomentumICloud") as? String)?.uppercased() == "YES"
  }

  /// Called when buckets were fetched (Dart pulls them).
  var onChanged: (() -> Void)?

  private let lock = NSLock()
  private var engine: CKSyncEngine?
  private var outbox: [String: String] = [:]
  private var inbox: [String: String] = [:]
  /// Each record's system fields (its change tag), so saving a bucket again
  /// updates it rather than clashing with the server's copy.
  private var systemFields: [String: Data] = [:]
  /// Something Dart has to hear about on its next call ("accountChanged",
  /// "deleted", "full").
  private var problem: String?
  /// What the last pull handed Dart: taken off the inbox once Dart says
  /// it's saved them (acknowledge), so an app stopped between the two
  /// gets them again.
  private var handedOver: [String: String] = [:]

  private lazy var container = CKContainer(identifier: Self.containerID)

  private lazy var folder: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    var url = base.appendingPathComponent("CloudSync", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
    return url
  }()

  private func file(_ name: String) -> URL { folder.appendingPathComponent(name) }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  // MARK: - Files

  private func load() {
    let decoder = JSONDecoder()
    locked {
      outbox = (try? decoder.decode([String: String].self, from: Data(contentsOf: file("outbox.json")))) ?? [:]
      inbox = (try? decoder.decode([String: String].self, from: Data(contentsOf: file("inbox.json")))) ?? [:]
      systemFields = (try? decoder.decode([String: Data].self, from: Data(contentsOf: file("records.json")))) ?? [:]
    }
  }

  private func save() {
    let encoder = JSONEncoder()
    let (outbox, inbox, fields) = locked { (self.outbox, self.inbox, self.systemFields) }
    try? encoder.encode(outbox).write(to: file("outbox.json"), options: .atomic)
    try? encoder.encode(inbox).write(to: file("inbox.json"), options: .atomic)
    try? encoder.encode(fields).write(to: file("records.json"), options: .atomic)
  }

  private func loadState() -> CKSyncEngine.State.Serialization? {
    guard let data = try? Data(contentsOf: file("state.json")) else { return nil }
    return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
  }

  // MARK: - The engine

  /// The engine, made the first time it's needed.
  private func syncEngine() -> CKSyncEngine {
    if let engine = locked({ self.engine }) { return engine }
    load()
    let state = loadState()
    let configuration = CKSyncEngine.Configuration(
      database: container.privateCloudDatabase,
      stateSerialization: state,
      delegate: self
    )
    let engine = CKSyncEngine(configuration)
    locked { self.engine = engine }
    // A fresh start (first time, or after a reset): make sure the zone is there
    if state == nil {
      engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
    }
    // Lets iCloud wake the app when another device changes something
    DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    return engine
  }

  /// Forgets the engine's place and everything waiting, so the next fetch
  /// starts from the beginning.
  private func reset() {
    locked {
      engine = nil
      outbox = [:]
      inbox = [:]
      handedOver = [:]
      systemFields = [:]
      problem = nil
    }
    for name in ["state.json", "outbox.json", "inbox.json", "records.json"] {
      try? FileManager.default.removeItem(at: file(name))
    }
  }

  private func takeProblem() throws {
    let problem = locked { () -> String? in
      let p = self.problem
      self.problem = nil
      return p
    }
    if let problem { throw SyncProblem(code: problem) }
  }

  // MARK: - On or off

  /// A file whose presence says sync is on here (Dart says so: setActive),
  /// so the engine can start at launch, before Flutter does.
  private var activeFile: URL { file("active") }

  var isOn: Bool { FileManager.default.fileExists(atPath: activeFile.path) }

  func setActive(_ active: Bool) {
    if active {
      FileManager.default.createFile(atPath: activeFile.path, contents: Data())
    } else {
      try? FileManager.default.removeItem(at: activeFile)
    }
  }

  /// At launch, with sync on: the engine listens for other devices' changes
  /// (iCloud's pushes) and fetches what it missed, app open or not.
  func startIfOn() {
    guard Self.isAvailableInBuild, isOn else { return }
    _ = syncEngine()
  }

  /// iCloud says something changed: fetches it into the inbox. True when
  /// there's something there for Dart to bring in.
  func fetchInBackground() async -> Bool {
    guard Self.isAvailableInBuild, isOn else { return false }
    let engine = syncEngine()
    do {
      try await engine.fetchChanges()
    } catch {
      // Offline and the like: whatever did arrive is in the inbox
    }
    return locked { !inbox.isEmpty }
  }

  // MARK: - What Dart calls

  func accountStatus() async -> String {
    guard Self.isAvailableInBuild else { return "unavailable" }
    do {
      switch try await container.accountStatus() {
      case .available: return "available"
      case .noAccount: return "noAccount"
      case .restricted: return "restricted"
      default: return "unavailable"
      }
    } catch {
      return "unavailable"
    }
  }

  func push(_ buckets: [String: String]) async throws {
    let engine = syncEngine()
    try takeProblem()
    locked { outbox.merge(buckets) { _, new in new } }
    save()
    engine.state.add(pendingRecordZoneChanges: buckets.keys.map {
      .saveRecord(CKRecord.ID(recordName: $0, zoneID: Self.zoneID))
    })
    try await engine.sendChanges()
    try takeProblem()
  }

  func pull() async throws -> [String: String] {
    let engine = syncEngine()
    try takeProblem()
    try await engine.fetchChanges()
    try takeProblem()
    // Kept until Dart has saved them
    return locked { () -> [String: String] in
      handedOver = inbox
      return inbox
    }
  }

  /// Dart saved these (from the last pull): they leave the inbox, unless a
  /// newer copy came in meanwhile.
  func acknowledge(_ names: [String]) {
    locked {
      for name in names where inbox[name] != nil && inbox[name] == handedOver[name] {
        inbox[name] = nil
      }
    }
    save()
  }

  func resetCursor() {
    reset()
  }

  func deleteAll() async throws {
    let engine = syncEngine()
    engine.state.add(pendingDatabaseChanges: [.deleteZone(Self.zoneID)])
    try await engine.sendChanges()
    reset()
  }

  // MARK: - CKSyncEngineDelegate

  func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    switch event {
    case .stateUpdate(let update):
      if let data = try? JSONEncoder().encode(update.stateSerialization) {
        try? data.write(to: file("state.json"), options: .atomic)
      }

    case .accountChange(let change):
      switch change.changeType {
      case .signIn:
        break
      case .signOut, .switchAccounts:
        reset()
        locked { problem = "accountChanged" }
        onChanged?()
      @unknown default:
        break
      }

    case .fetchedDatabaseChanges(let changes):
      // The copy deleted from another device
      if changes.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
        reset()
        locked { problem = "deleted" }
        onChanged?()
      }

    case .fetchedRecordZoneChanges(let changes):
      var any = false
      locked {
        for modification in changes.modifications {
          let record = modification.record
          remember(record)
          guard let contents = record["data"] as? String else { continue }
          inbox[record.recordID.recordName] = contents
          any = true
        }
      }
      save()
      if any { onChanged?() }

    case .sentRecordZoneChanges(let sent):
      var again: [CKSyncEngine.PendingRecordZoneChange] = []
      locked {
        for record in sent.savedRecords {
          remember(record)
        }
        for failure in sent.failedRecordSaves {
          let id = failure.record.recordID
          switch failure.error.code {
          case .serverRecordChanged:
            // Saved before from here (or a copy of this device): take the
            // server's change tag and save this device's contents again
            if let server = failure.error.serverRecord { remember(server) }
            again.append(.saveRecord(id))
          case .zoneNotFound:
            again.append(.saveRecord(id))
          case .quotaExceeded:
            problem = "full"
          case .unknownItem:
            systemFields[id.recordName] = nil
            again.append(.saveRecord(id))
          default:
            // Network and the like: the engine keeps it and tries again
            break
          }
        }
      }
      if sent.failedRecordSaves.contains(where: { $0.error.code == .zoneNotFound }) {
        syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
      }
      if !again.isEmpty { syncEngine.state.add(pendingRecordZoneChanges: again) }
      save()

    default:
      break
    }
  }

  func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext,
    syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
    return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { id in
      guard let contents = self.locked({ self.outbox[id.recordName] }) else {
        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
        return nil
      }
      let record = self.locked { self.record(for: id) }
      record["data"] = contents as CKRecordValue
      record["device"] = (id.recordName.components(separatedBy: "~").first ?? "") as CKRecordValue
      record["schema"] = Self.schema as CKRecordValue
      return record
    }
  }

  // MARK: - Records (call with the lock held)

  private func remember(_ record: CKRecord) {
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    record.encodeSystemFields(with: archiver)
    archiver.finishEncoding()
    systemFields[record.recordID.recordName] = archiver.encodedData
    // Sent: no longer waiting
    if record.recordType == Self.recordType, let sent = record["data"] as? String,
       outbox[record.recordID.recordName] == sent {
      outbox[record.recordID.recordName] = nil
    }
  }

  private func record(for id: CKRecord.ID) -> CKRecord {
    if let data = systemFields[id.recordName],
       let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
      unarchiver.requiresSecureCoding = true
      if let record = CKRecord(coder: unarchiver) { return record }
    }
    return CKRecord(recordType: Self.recordType, recordID: id)
  }
}

/// Something to tell Dart, as one of its CloudProblem codes.
struct SyncProblem: Error {
  let code: String
}

/// `momentum/sync`: how Dart reaches [CloudSync], from the app or from the
/// engine that works in the background (BackgroundRun).
enum SyncChannel {
  private static var app: FlutterMethodChannel?
  private static var background: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger, inBackground: Bool = false) {
    let channel = FlutterMethodChannel(name: "momentum/sync", binaryMessenger: messenger)
    if inBackground {
      background = channel
    } else {
      app = channel
    }
    // Fetched buckets: whichever Dart is running hears of them
    CloudSync.shared.onChanged = {
      DispatchQueue.main.async {
        (BackgroundRun.appIsRunning ? SyncChannel.app : SyncChannel.background)?
          .invokeMethod("changed", arguments: nil)
      }
    }
    channel.setMethodCallHandler { call, result in
      let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
      // Nothing touches CloudKit in a build signed without iCloud
      if call.method != "accountStatus" && !CloudSync.isAvailableInBuild {
        reply(FlutterError(code: "other", message: "This build has no iCloud", details: nil))
        return
      }
      Task {
        do {
          switch call.method {
          case "accountStatus":
            reply(await CloudSync.shared.accountStatus())
          case "push":
            let buckets = (call.arguments as? [String: Any])?["buckets"] as? [String: String] ?? [:]
            try await CloudSync.shared.push(buckets)
            reply(nil)
          case "pull":
            reply(try await CloudSync.shared.pull())
          case "acknowledge":
            let names = (call.arguments as? [String: Any])?["names"] as? [String] ?? []
            CloudSync.shared.acknowledge(names)
            reply(nil)
          case "setActive":
            CloudSync.shared.setActive((call.arguments as? [String: Any])?["active"] as? Bool ?? false)
            reply(nil)
          case "resetCursor":
            CloudSync.shared.resetCursor()
            reply(nil)
          case "deleteAll":
            try await CloudSync.shared.deleteAll()
            reply(nil)
          default:
            reply(FlutterMethodNotImplemented)
          }
        } catch let problem as SyncProblem {
          reply(FlutterError(code: problem.code, message: nil, details: nil))
        } catch let error as CKError {
          reply(FlutterError(code: code(for: error), message: error.localizedDescription, details: nil))
        } catch {
          reply(FlutterError(code: "other", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// The background engine ended.
  static func backgroundEnded() {
    background = nil
  }

  /// What Dart's CloudProblem calls a CloudKit error.
  static func code(for error: CKError) -> String {
    switch error.code {
    case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
      return "offline"
    case .quotaExceeded:
      return "full"
    case .notAuthenticated, .accountTemporarilyUnavailable:
      return "accountChanged"
    case .userDeletedZone:
      return "deleted"
    default:
      return "other"
    }
  }
}

/// Work while the app isn't on screen (lib/core/background/background_refresh.dart):
/// another device's changes when iCloud says there are some (a push), and
/// iOS's background refresh every so often (Health, sync, notifications
/// planned again, the widgets). With the app running (even suspended in
/// the background) its own Dart does it; otherwise an engine of its own
/// starts at `backgroundMain`, and an app opening meanwhile waits for it
/// (`waitIdle`, at most a few seconds), so two never write at once.
enum BackgroundRun {
  static let refreshTask = "com.paulblake.momentum.refresh"

  /// What happened, for Console (never anything about the person's habits).
  private static let log = Logger(subsystem: "com.paulblake.momentum", category: "background")

  private static func trace(_ message: String) {
    log.notice("\(message, privacy: .public)")
    // Debug builds: in the simulator's log too (Logger's lines don't show there)
    if _isDebugAssertConfiguration() { NSLog("BackgroundRun: %@", message) }
  }

  /// The app's own engine, while it's alive (iOS can let a window go and
  /// keep the process), and its channel.
  private static weak var appEngine: FlutterEngine?
  private static var appChannel: FlutterMethodChannel?

  static var appIsRunning: Bool { appEngine != nil && appChannel != nil }

  /// The engine working in the background, and why it was started.
  private static var engine: FlutterEngine?
  private static var reason = "refresh"
  /// Which start this is, so a timeout only ends its own.
  private static var started = 0
  private static var finishing: [(Bool) -> Void] = []
  private static var opening: [() -> Void] = []

  /// How long a run may take: iOS gives about 30 seconds.
  private static let most: TimeInterval = 25
  /// How long the app, opening, waits for a run before ending it.
  private static let openWait: TimeInterval = 4

  /// The app's engine is up (called before its Dart runs).
  static func registerApp(engine: FlutterEngine?, messenger: FlutterBinaryMessenger) {
    appEngine = engine
    let channel = FlutterMethodChannel(name: "momentum/background", binaryMessenger: messenger)
    appChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "waitIdle": waitIdle { result(nil) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  /// A push: from iCloud ("push"), or a test one carrying `momentum`
  /// ("push" or "refresh", for trying this on a simulator). Nil for any other.
  static func reason(forPush userInfo: [AnyHashable: Any]) -> String? {
    if let test = userInfo["momentum"] as? String, test == "push" || test == "refresh" { return test }
    if CloudSync.isAvailableInBuild, CKNotification(fromRemoteNotificationDictionary: userInfo) != nil { return "push" }
    return nil
  }

  /// Fetches what iCloud has (with sync on), then has Dart bring it in;
  /// [completion] says whether there was anything.
  static func push(_ reason: String, completion: @escaping (Bool) -> Void) {
    trace("Push (\(reason))")
    // Once, on the main thread, and in time: iOS allows about 30 seconds
    var answered = false
    let answer: (Bool) -> Void = { ok in
      onMain {
        guard !answered else { return }
        answered = true
        completion(ok)
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { answer(false) }
    Task {
      let waiting = await CloudSync.shared.fetchInBackground()
      // A test refresh runs anyway; a push only when something came
      guard waiting || reason == "refresh" else { return answer(false) }
      run(reason, completion: answer)
    }
  }

  /// Has Dart do the work for [reason]: the app's own, or the background
  /// engine's. [completion] runs once, on the main thread. [force] starts
  /// the background engine even with the app opening on screen (a test).
  static func run(_ reason: String, force: Bool = false, completion: @escaping (Bool) -> Void) {
    onMain {
      var answered = false
      let answer: (Bool) -> Void = { ok in
        guard !answered else { return }
        answered = true
        completion(ok)
      }
      if appIsRunning, let channel = appChannel {
        trace("Run (\(reason)) in the app")
        channel.invokeMethod("run", arguments: reason) { reply in
          DispatchQueue.main.async { answer((reply as? Bool) ?? false) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + most) { answer(false) }
        return
      }
      // Opening on screen, its engine not up yet: the app does all this as
      // it loads, and a second engine beside it would only hold the launch
      if engine == nil, !force, UIApplication.shared.applicationState != .background {
        trace("Run (\(reason)) left to the app opening")
        return answer(true)
      }
      finishing.append(answer)
      // Already running: hears when it ends
      if engine == nil { start(reason) }
    }
  }

  /// [body] on the main thread: now if this is it, else next.
  private static func onMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread {
      body()
    } else {
      DispatchQueue.main.async(execute: body)
    }
  }

  private static func start(_ reason: String) {
    trace("Run (\(reason)) in a background engine")
    self.reason = reason
    let engine = FlutterEngine(name: "momentum.background", project: nil, allowHeadlessExecution: true)
    let library = "package:atomic_momentum/core/background/background_refresh.dart"
    guard engine.run(withEntrypoint: "backgroundMain", libraryURI: library) else {
      return end(false)
    }
    GeneratedPluginRegistrant.register(with: engine)
    let messenger = engine.binaryMessenger
    SyncChannel.register(messenger: messenger, inBackground: true)
    BackgroundWidgets.register(messenger: messenger)
    let channel = FlutterMethodChannel(name: "momentum/background", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reason":
        result(BackgroundRun.reason)
      case "done":
        result(nil)
        end((call.arguments as? Bool) ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.engine = engine
    started += 1
    let run = started
    DispatchQueue.main.asyncAfter(deadline: .now() + most) {
      if started == run { end(false) }
    }
  }

  /// Ends the background engine (after it said it's done, or when time is
  /// up) and tells whoever was waiting.
  private static func end(_ ok: Bool) {
    if let running = engine {
      trace("Background engine ended (\(ok ? "done" : "stopped"))")
      engine = nil
      started += 1
      SyncChannel.backgroundEnded()
      // After the reply to "done" has gone out
      DispatchQueue.main.async { running.destroyContext() }
    }
    let done = finishing
    finishing = []
    done.forEach { $0(ok) }
    let waiting = opening
    opening = []
    waiting.forEach { $0() }
  }

  /// The app opening: goes once nothing runs in the background, ending a
  /// run that takes longer than [openWait].
  private static func waitIdle(_ go: @escaping () -> Void) {
    guard engine != nil else { return go() }
    trace("The app opens: waiting for the background engine")
    opening.append(go)
    let run = started
    DispatchQueue.main.asyncAfter(deadline: .now() + openWait) {
      if started == run { end(false) }
    }
  }

  // MARK: - iOS's background refresh

  /// At launch (iOS wants it registered before launch ends).
  static func registerRefresh() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTask, using: nil) { task in
      trace("Background refresh")
      scheduleRefresh()
      var completed = false
      let complete: (Bool) -> Void = { ok in
        DispatchQueue.main.async {
          guard !completed else { return }
          completed = true
          task.setTaskCompleted(success: ok)
        }
      }
      task.expirationHandler = {
        DispatchQueue.main.async { end(false) }
        complete(false)
      }
      Task {
        _ = await CloudSync.shared.fetchInBackground()
        run("refresh", completion: complete)
      }
    }
  }

  /// Asks iOS for a refresh in half an hour or so (it decides when).
  static func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTask)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      trace("Couldn't ask for a background refresh: \(error.localizedDescription)")
    }
  }

  /// Debug builds launched with `-momentumBackgroundTest YES` start a
  /// background run at launch, before the app's engine: the background
  /// engine, and the app waiting for it, tried on a simulator.
  static func testAtLaunch() {
    guard _isDebugAssertConfiguration(), UserDefaults.standard.bool(forKey: "momentumBackgroundTest") else { return }
    trace("Test: a background run at launch")
    run("refresh", force: true) { ok in trace("Test run finished: \(ok)") }
  }
}

/// `momentum/widgets` for the background engine: writes the widgets'
/// snapshot and hands over taps queued on them, nothing that needs the
/// app on screen (WidgetChannel is the app's).
enum BackgroundWidgets {
  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "momentum/widgets", binaryMessenger: messenger).setMethodCallHandler { call, result in
      switch call.method {
      case "save":
        if let json = call.arguments as? String {
          WidgetStore.saveSnapshot(json)
          WatchLink.send(json)
        }
        result(nil)
      case "takeLogs":
        result(WidgetStore.takeLogs())
      case "applied", "takeOpened":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
