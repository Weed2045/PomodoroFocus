import Foundation

protocol AppStateRepository {
    func load() -> AppState
    func save(_ state: AppState)
}

