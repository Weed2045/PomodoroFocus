import Foundation

final class AmbientSoundRepositoryImpl: AmbientSoundRepositoryProtocol {
    private let defaults: UserDefaults
    private let playerKey = "ambient_player_state_v1"
    private let focusKey = "focus_mode_settings_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPlayerState() -> AmbientPlayerState {
        guard
            let data = defaults.data(forKey: playerKey),
            var state = try? decoder.decode(AmbientPlayerState.self, from: data)
        else { return .default }

        let defaultsBySound = Dictionary(uniqueKeysWithValues: AmbientPlayerState.default.tracks.map { ($0.sound, $0) })
        let knownTracks = Dictionary(uniqueKeysWithValues: state.tracks.map { ($0.sound, $0) })
        state.tracks = AmbientSound.allCases.compactMap { sound in
            knownTracks[sound] ?? defaultsBySound[sound]
        }
        return state
    }

    func savePlayerState(_ state: AmbientPlayerState) {
        defaults.set(try? encoder.encode(state), forKey: playerKey)
    }

    func loadFocusModeSettings() -> FocusModeSettings {
        guard
            let data = defaults.data(forKey: focusKey),
            let settings = try? decoder.decode(FocusModeSettings.self, from: data)
        else { return .default }
        return settings
    }

    func saveFocusModeSettings(_ settings: FocusModeSettings) {
        defaults.set(try? encoder.encode(settings), forKey: focusKey)
    }
}
