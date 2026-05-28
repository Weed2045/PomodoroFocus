import Foundation

@MainActor
final class SplashViewModel: ObservableObject {
    private let firstLaunchStore: FirstLaunchStore

    init(firstLaunchStore: FirstLaunchStore) {
        self.firstLaunchStore = firstLaunchStore
    }

    func prepareLaunch() async {
        if firstLaunchStore.isFirstLaunch {
            firstLaunchStore.markFirstLaunchHandled()
        }

        try? await Task.sleep(nanoseconds: 1_700_000_000)
    }
}

