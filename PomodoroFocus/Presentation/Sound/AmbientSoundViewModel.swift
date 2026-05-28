import Combine
import Foundation

@MainActor
final class AmbientSoundViewModel: ObservableObject {
    @Published var tracks: [SoundTrackState] = []
    @Published var masterVolume: Float = 0.7
    @Published var isPlaying = false
    @Published var autoPlayWithTimer = true
    @Published var focusSettings: FocusModeSettings = .default
    @Published var dimmingOpacity: Double = 0

    private let coordinator: FocusModeCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: FocusModeCoordinator) {
        self.coordinator = coordinator
        syncFromCoordinator()
        bindCoordinator()
    }

    func toggleTrack(_ sound: AmbientSound) {
        coordinator.toggleTrack(sound)
        syncFromCoordinator()
    }

    func setVolume(_ volume: Float, for sound: AmbientSound) {
        coordinator.setVolume(volume, for: sound)
        if let index = tracks.firstIndex(where: { $0.sound == sound }) {
            tracks[index].volume = min(max(volume, 0), 1)
        }
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = min(max(volume, 0), 1)
        coordinator.setMasterVolume(masterVolume)
    }

    func setAutoPlayWithTimer(_ enabled: Bool) {
        autoPlayWithTimer = enabled
        coordinator.setAutoPlayWithTimer(enabled)
    }

    func togglePlayback() {
        if isPlaying {
            coordinator.stopAudio(fadeOut: true)
        } else {
            coordinator.startAudio()
        }
        syncFromCoordinator()
    }

    func toggleFocusMode() {
        if coordinator.isActive {
            Task { await coordinator.deactivate() }
        } else {
            Task { await coordinator.activate() }
        }
    }

    func updateSettings(_ settings: FocusModeSettings) {
        focusSettings = settings
        coordinator.updateFocusSettings(settings)
        dimmingOpacity = coordinator.isActive ? settings.dimUILevel : 0
    }

    private func syncFromCoordinator() {
        tracks = coordinator.playerState.tracks.filter(\.isAvailable)
        masterVolume = coordinator.playerState.masterVolume
        isPlaying = coordinator.isAudioPlaying
        autoPlayWithTimer = coordinator.playerState.autoPlayWithTimer
        focusSettings = coordinator.focusSettings
        dimmingOpacity = coordinator.isActive ? coordinator.focusSettings.dimUILevel : 0
    }

    private func bindCoordinator() {
        coordinator.$isAudioPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)

        coordinator.$isActive
            .receive(on: RunLoop.main)
            .map { [weak self] active in
                active ? (self?.focusSettings.dimUILevel ?? 0.6) : 0
            }
            .assign(to: &$dimmingOpacity)
    }
}
