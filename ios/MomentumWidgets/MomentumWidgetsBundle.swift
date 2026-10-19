import SwiftUI
import WidgetKit

/// Momentum's home screen and lock screen widgets. They draw the snapshot the
/// app writes to the App Group (docs/design/widgets.md).
@main
struct MomentumWidgetsBundle: WidgetBundle {
  var body: some Widget {
    HabitWidget()
    GroupWidget()
    MomentumWidget()
    QuoteWidget()
    InsightsWidget()
    IWillWidget()
    TodayWidget()
  }
}
