import XCTest

/// App Store screenshots of Momentum's widgets on the home screen and the lock
/// screen (tool/widget_screens.sh). Drives SpringBoard by name where it says,
/// by position where it doesn't (the lock screen editor; iOS 27 on the 6.9"
/// iPhone 17 Pro Max, so another phone or iOS may need the positions moved).
final class WidgetScreens: XCTestCase {
  let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
  /// The lock screen editor and its widget gallery run in PosterBoard.
  let posters = XCUIApplication(bundleIdentifier: "com.apple.PosterBoard")
  var dir: String { ProcessInfo.processInfo.environment["SCREENS_DIR"] ?? "/tmp" }

  func shot(_ name: String) {
    let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
  }

  func lock() {
    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    sleep(2)
  }

  func tap(_ x: Double, _ y: Double, wait: UInt32 = 2) {
    springboard.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    sleep(wait)
  }

  func drag(from: (Double, Double), to: (Double, Double), wait: UInt32 = 2) {
    let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: from.0, dy: from.1))
    start.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: to.0, dy: to.1)))
    sleep(wait)
  }

  /// From the home screen to the lock screen editor's widget gallery.
  func openLockGallery() {
    springboard.activate()
    sleep(1)
    lock()
    springboard.tap()
    sleep(2)
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2.0)
    sleep(2)
    springboard.buttons["Customize"].tap()
    sleep(3)
    tap(0.5, 0.79, wait: 3)
  }

  /// Momentum's page in the lock screen gallery: its row, after Maps
  /// (iOS 27, 6.9" phone).
  func openMomentumInGallery() {
    tap(0.3, 0.918, wait: 3)
  }

  /// The gallery's next widget kind (they page sideways).
  func nextKind() { drag(from: (0.85, 0.705), to: (0.15, 0.705)) }

  /// Home screen edit mode (the icons jiggle). A long press that lands on a
  /// widget opens its menu instead, which has "Edit Home Screen".
  func editHome() {
    springboard.activate()
    XCUIDevice.shared.press(.home)
    sleep(2)
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(forDuration: 1.6)
    sleep(2)
    let menu = springboard.buttons["Edit Home Screen"]
    if menu.exists { menu.tap(); sleep(2) }
  }

  /// The widget gallery's next page (a real swipe: a press and drag would
  /// pick the widget up).
  func nextGalleryPage() {
    springboard.swipeLeft()
    sleep(1)
  }

  /// Takes the simulator's own widgets off the first page. A widget is an
  /// icon wider than an app's; its "–" sits at its top-left corner. Anything
  /// that asks about an app is cancelled.
  func removeHomeWidgets() {
    let cancel = springboard.buttons["Cancel"]
    if cancel.exists { cancel.tap(); sleep(1) }
    editHome()
    for _ in 0..<6 {
      let widget = springboard.icons.allElementsBoundByIndex.first { $0.frame.width > 120 && $0.frame.minY > 40 && $0.isHittable }
      guard let widget else { break }
      let corner = CGPoint(x: widget.frame.minX, y: widget.frame.minY)
      let delete = springboard.buttons.matching(identifier: "DeleteButton").allElementsBoundByIndex
        .min { hypot($0.frame.midX - corner.x, $0.frame.midY - corner.y) < hypot($1.frame.midX - corner.x, $1.frame.midY - corner.y) }
      guard let delete, hypot(delete.frame.midX - corner.x, delete.frame.midY - corner.y) < 40 else { break }
      delete.tap()
      sleep(1)
      let remove = springboard.buttons["Remove"]
      if remove.waitForExistence(timeout: 2) {
        remove.tap()
      } else {
        if cancel.exists { cancel.tap() }
        break
      }
      sleep(2)
    }
    let done = springboard.buttons["Done"]
    if done.exists { done.tap(); sleep(1) }
  }

  /// Adds the gallery's widget [page] (kinds and sizes, in order) to the top
  /// of the home screen.
  func addHomeWidget(page: Int) {
    editHome()
    springboard.buttons["Edit"].tap()
    sleep(1)
    springboard.descendants(matching: .any)["Add Widget"].firstMatch.tap()
    sleep(4)
    let search = springboard.searchFields.firstMatch
    if search.waitForExistence(timeout: 3) { search.tap() } else { tap(0.5, 0.2) }
    springboard.typeText("Momentum")
    sleep(3)
    let result = springboard.descendants(matching: .any).matching(NSPredicate(format: "label == 'Momentum'")).allElementsBoundByIndex
      .first { $0.frame.minY > 120 && $0.isHittable }
    if let result { result.tap() } else { tap(0.33, 0.29) }
    sleep(3)
    for _ in 0..<page { nextGalleryPage() }
    sleep(1)
    springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch.tap()
    sleep(2)
    let done = springboard.buttons["Done"]
    if done.waitForExistence(timeout: 3) { done.tap() }
    sleep(2)
  }

  /// The home screen with Momentum's widgets: Habit and Momentum (small)
  /// side by side, then Habits and Quote (medium). Each goes in at the top,
  /// so they're added bottom first.
  func testHomeScreen() throws {
    removeHomeWidgets()
    addHomeWidget(page: 8)   // Quote, medium
    addHomeWidget(page: 3)   // Habits, medium
    addHomeWidget(page: 5)   // Momentum, small
    addHomeWidget(page: 0)   // Habit, small
    XCUIDevice.shared.press(.home)
    sleep(3)
    shot("home_widgets")
  }

  /// The lock screen with Momentum's widgets: the Habit rectangle (with its
  /// +), Momentum and the Streak, round.
  func testLockScreen() throws {
    openLockGallery()
    openMomentumInGallery()
    tap(0.6, 0.705)          // Habit, rectangle
    nextKind()
    tap(0.27, 0.705)         // Momentum, round
    for _ in 0..<4 { nextKind() }
    tap(0.5, 0.705)          // Streak, round
    tap(0.913, 0.473)        // close Momentum's page
    tap(0.5, 0.093)          // close the list
    tap(0.85, 0.037, wait: 3) // Done
    tap(0.5, 0.45, wait: 3)  // pick the edited lock screen
    shot("lock_screen")
  }
}
