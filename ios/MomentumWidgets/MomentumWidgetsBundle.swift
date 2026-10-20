import SwiftUI
import WidgetKit

/// Momentum's home screen and lock screen widgets, and (iOS 18) the "Log a
/// habit" control. They draw the snapshot the app writes to the App Group
/// (docs/design/widgets.md).
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
    StreakWidget()
    if #available(iOS 18.0, *) {
      LogHabitControl()
    }
  }
}
