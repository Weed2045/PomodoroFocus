import Foundation

struct GetAppStateUseCase {
    private let repository: AppStateRepository

    init(repository: AppStateRepository) {
        self.repository = repository
    }

    func execute() -> AppState {
        repository.load().normalizedForToday()
    }
}

