import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(hex: "#1C1C1E"))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                Text(context.state.sessionType.emoji)
                    .font(.system(size: 16))
            } compactTrailing: {
                CompactCountdownView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .keylineTint(Color(hex: context.state.sessionType.accentColorHex))
            .widgetURL(URL(string: "pomodoro://focus"))
        }
    }
}

