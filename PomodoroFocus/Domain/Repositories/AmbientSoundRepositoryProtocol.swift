import Foundation

protocol AmbientSoundRepositoryProtocol {
    func loadPlayerState() -> AmbientPlayerState
    func savePlayerState(_ state: AmbientPlayerState)
    func loadFocusModeSettings() -> FocusModeSettings
    func saveFocusModeSettings(_ settings: FocusModeSettings)
}
