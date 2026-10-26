import CloudKit
import Flutter
import UIKit

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
    let fetched = locked { () -> [String: String] in
      let all = inbox
      inbox = [:]
      return all
    }
    save()
    return fetched
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

/// `momentum/sync`: how Dart reaches [CloudSync].
enum SyncChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "momentum/sync", binaryMessenger: messenger)
    CloudSync.shared.onChanged = {
      DispatchQueue.main.async { channel.invokeMethod("changed", arguments: nil) }
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
