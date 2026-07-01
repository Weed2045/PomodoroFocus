import SwiftUI

@main
struct PomodoroFocusApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .onOpenURL { url in
                    handleDeeplink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                AppLogger.app.info("⚡️ Scene → active")
                container.pomodoroService.refreshTimerState()
            case .background:
                AppLogger.app.info("🌙 Scene → background")
                container.pomodoroService.handleAppDidEnterBackground()
            case .inactive:
                AppLogger.app.debug("💤 Scene → inactive")
            @unknown default:
                AppLogger.app.warning("❓ Scene → unknown phase")
            }
        }
    }

    private func handleDeeplink(_ url: URL) {
        switch url.host {
        case "focus":
            NotificationCenter.default.post(name: .navigateToFocus, object: nil)
        case "toggle":
            toggleTimerFromLiveActivityLink()
        default:
            break
        }
    }

    private func toggleTimerFromLiveActivityLink() {
        container.pomodoroService.refreshTimerState()

        switch container.pomodoroService.currentState.status {
        case .running:
            container.pomodoroService.pause()
        case .paused:
            container.pomodoroService.resume()
        case .idle, .completed:
            break
        }
    }
}
