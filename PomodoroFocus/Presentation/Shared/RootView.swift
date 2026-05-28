import SwiftUI

enum AppRoute: Hashable {
    case timer
    case settings
}

struct RootView: View {
    let container: AppDIContainer
    @State private var hasFinishedSplash = false

    var body: some View {
        Group {
            if hasFinishedSplash {
                MainTabView(container: container)
                    .transition(.opacity)
            } else {
                SplashView(viewModel: container.makeSplashViewModel()) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasFinishedSplash = true
                    }
                }
                .transition(.opacity)
            }
        }
        // Always render in light mode regardless of device setting.
        .preferredColorScheme(.light)
    }
}

// MARK: – Main Tab View ───────────────────────────────────────────────────────

struct MainTabView: View {
    let container: AppDIContainer
    @State private var focusPath = NavigationPath()
    @StateObject private var documentListVM: DocumentListViewModel
    @StateObject private var soundVM: AmbientSoundViewModel

    init(container: AppDIContainer) {
        self.container = container
        _documentListVM = StateObject(wrappedValue: container.makeDocumentListViewModel())
        _soundVM = StateObject(wrappedValue: container.makeAmbientSoundViewModel())
    }

    var body: some View {
        TabView {
            // ── Focus tab ──────────────────────────────────────────────
            NavigationStack(path: $focusPath) {
                HomeView(viewModel: container.makeHomeViewModel(), path: $focusPath)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .timer:
                            TimerView(
                                viewModel: container.makeTimerViewModel(),
                                soundViewModel: soundVM
                            )
                        case .settings:
                            SettingsView(
                                viewModel: container.makeSettingsViewModel(),
                                soundViewModel: soundVM
                            )
                        }
                    }
            }
            .tabItem {
                Label(L10n.Tab.focus, systemImage: "timer.circle.fill")
            }

            // ── Calendar tab ───────────────────────────────────────────
            NavigationStack {
                CalendarView(viewModel: container.makeCalendarViewModel())
            }
            .tabItem {
                Label(L10n.Tab.calendar, systemImage: "calendar")
            }

            // ── Analytics tab ─────────────────────────────────────────
            NavigationStack {
                AnalyticsView(viewModel: container.makeAnalyticsViewModel())
            }
            .tabItem {
                Label(L10n.Tab.analytics, systemImage: "chart.xyaxis.line")
            }

            // ── Scanner tab ────────────────────────────────────────────
            NavigationStack {
                DocumentListView(viewModel: documentListVM)
            }
            .tabItem {
                Label(L10n.Tab.scanner, systemImage: "doc.viewfinder.fill")
            }
        }
        .tint(AppTheme.blue)
        .modifier(FocusDimmingModifier(viewModel: soundVM))
    }
}
