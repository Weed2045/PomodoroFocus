import Foundation

protocol FirstLaunchStore {
    var isFirstLaunch: Bool { get }
    func markFirstLaunchHandled()
}

