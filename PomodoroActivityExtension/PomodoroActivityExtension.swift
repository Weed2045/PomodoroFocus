import SwiftUI
import WidgetKit

@main
struct PomodoroActivityBundle: WidgetBundle {
    var body: some Widget {
        PomodoroFocusWidget()
        PomodoroLiveActivityWidget()
    }
}
