import SwiftUI

enum AppRoute: Hashable {
    case timer
    case settings
}

struct RootView: View {
    let container: AppDIContainer
    @State private var hasFinishedSplash = false
    @State private var focusNavigationRequest = 0

    var body: some View {
        Group {
            if hasFinishedSplash {
                MainTabView(
                    container: container,
                    focusNavigationRequest: focusNavigationRequest
                )
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToFocus)) { _ in
            focusNavigationRequest += 1
            if !hasFinishedSplash {
                withAnimation(.easeInOut(duration: 0.35)) {
                    hasFinishedSplash = true
                }
            }
        }
    }
}

// MARK: – Main Tab View ───────────────────────────────────────────────────────

private enum MainTab: Hashable {
    case focus
    case calendar
    case analytics
    case scanner
}

struct MainTabView: View {
    let container: AppDIContainer
    let focusNavigationRequest: Int
    @State private var selectedTab: MainTab = .focus
    @State private var focusPath = NavigationPath()
    @State private var handledFocusNavigationRequest = 0
    @StateObject private var documentListVM: DocumentListViewModel
    @StateObject private var soundVM: AmbientSoundViewModel

    init(container: AppDIContainer, focusNavigationRequest: Int = 0) {
        self.container = container
        self.focusNavigationRequest = focusNavigationRequest
        _documentListVM = StateObject(wrappedValue: container.makeDocumentListViewModel())
        _soundVM = StateObject(wrappedValue: container.makeAmbientSoundViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
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
            .tag(MainTab.focus)

            // ── Calendar tab ───────────────────────────────────────────
            NavigationStack {
                CalendarView(viewModel: container.makeCalendarViewModel())
            }
            .tabItem {
                Label(L10n.Tab.calendar, systemImage: "calendar")
            }
            .tag(MainTab.calendar)

            // ── Analytics tab ─────────────────────────────────────────
            NavigationStack {
                AnalyticsView(viewModel: container.makeAnalyticsViewModel())
            }
            .tabItem {
                Label(L10n.Tab.analytics, systemImage: "chart.xyaxis.line")
            }
            .tag(MainTab.analytics)

            // ── Scanner tab ────────────────────────────────────────────
            NavigationStack {
                DocumentListView(viewModel: documentListVM)
            }
            .tabItem {
                Label(L10n.Tab.scanner, systemImage: "doc.viewfinder.fill")
            }
            .tag(MainTab.scanner)
        }
        .tint(AppTheme.blue)
        .modifier(FocusDimmingModifier(viewModel: soundVM))
        .task(id: focusNavigationRequest) {
            guard focusNavigationRequest > 0,
                  handledFocusNavigationRequest != focusNavigationRequest else { return }
            handledFocusNavigationRequest = focusNavigationRequest
            selectedTab = .focus
            focusPath = NavigationPath()
            focusPath.append(AppRoute.timer)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScannedDocument)) { notification in
            guard let documentID = notification.userInfo?[AppNavigationUserInfoKey.documentID] as? UUID else {
                return
            }
            selectedTab = .scanner
            documentListVM.openDocument(id: documentID)
        }
    }
}
