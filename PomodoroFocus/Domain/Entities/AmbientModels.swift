import Foundation

enum AmbientSound: String, CaseIterable, Codable, Identifiable {
    case rain = "ambient_rain"
    case cafe = "ambient_cafe"
    case forest = "ambient_forest"
    case whiteNoise = "ambient_whitenoise"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain:       L10n.Sound.trackRain
        case .cafe:       L10n.Sound.trackCafe
        case .forest:     L10n.Sound.trackForest
        case .whiteNoise: L10n.Sound.trackWhiteNoise
        }
    }

    var icon: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .cafe: "cup.and.saucer.fill"
        case .forest: "tree.fill"
        case .whiteNoise: "waveform"
        }
    }

    var accentHex: String {
        switch self {
        case .rain: "#4A90D9"
        case .cafe: "#C0845A"
        case .forest: "#4CAF50"
        case .whiteNoise: "#9B59B6"
        }
    }

    var fileName: String { rawValue }
    var fileExtension: String { "m4a" }
}

struct SoundTrackState: Codable, Identifiable, Equatable {
    let sound: AmbientSound
    var volume: Float
    var isEnabled: Bool
    var isAvailable: Bool = true

    var id: AmbientSound.ID { sound.id }
}

struct AmbientPlayerState: Codable {
    var tracks: [SoundTrackState]
    var masterVolume: Float
    var isPlaying: Bool
    var autoPlayWithTimer: Bool
    var fadeInDuration: Double
    var fadeOutDuration: Double

    static var `default`: Self {
        .init(
            tracks: AmbientSound.allCases.map {
                SoundTrackState(
                    sound: $0,
                    volume: $0 == .whiteNoise ? 0.3 : 0.5,
                    isEnabled: $0 == .rain
                )
            },
            masterVolume: 0.7,
            isPlaying: false,
            autoPlayWithTimer: true,
            fadeInDuration: 1.5,
            fadeOutDuration: 2.0
        )
    }
}

struct FocusModeSettings: Codable, Equatable {
    var isEnabled: Bool
    var autoActivateWithTimer: Bool
    var dimUILevel: Double
    var enableFocusFilter: Bool
    var pauseMusicWhenAmbientPlays: Bool

    static var `default`: Self {
        .init(
            isEnabled: true,
            autoActivateWithTimer: true,
            dimUILevel: 0.6,
            enableFocusFilter: true,
            pauseMusicWhenAmbientPlays: false
        )
    }
}
