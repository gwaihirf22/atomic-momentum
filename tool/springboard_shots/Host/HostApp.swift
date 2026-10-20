import SwiftUI

/// Only there so the UI test has an app to run beside; the test drives
/// SpringBoard.
@main
struct HostApp: App {
  var body: some Scene { WindowGroup { Text("Widget screens") } }
}
