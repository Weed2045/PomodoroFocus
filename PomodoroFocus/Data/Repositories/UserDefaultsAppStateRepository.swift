import Foundation

final class UserDefaultsAppStateRepository: AppStateRepository {
    private let defaults: UserDefaults
    private let key = "appState"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> AppState {
        UserDefaultsCoding.load(AppState.self, key: key, defaults: defaults) ?? .initial
    }

    func save(_ state: AppState) {
        UserDefaultsCoding.save(state, key: key, defaults: defaults)
    }
}

