import Foundation

final class UserDefaultsFirstLaunchStore: FirstLaunchStore {
    private let defaults: UserDefaults
    private let key = "hasHandledFirstLaunch"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var isFirstLaunch: Bool {
        !defaults.bool(forKey: key)
    }

    func markFirstLaunchHandled() {
        defaults.set(true, forKey: key)
    }
}

