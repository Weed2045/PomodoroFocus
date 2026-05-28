import Combine
import Foundation
import UIKit

@MainActor
final class FocusModeCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isAudioPlaying = false

    private let audioEngine: AmbientAudioEngine
    private let interruptionHandler: AudioInterruptionHandler
    private let focusFilterService: FocusFilterService
    private let repository: AmbientSoundRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var audioStartedByFocusMode = false

    private(set) var playerState: AmbientPlayerState
    private(set) var focusSettings: FocusModeSettings

    init(
        audioEngine: AmbientAudioEngine,
        interruptionHandler: AudioInterruptionHandler,
        focusFilterService: FocusFilterService,
        repository: AmbientSoundRepositoryProtocol
    ) {
        self.audioEngine = audioEngine
        self.interruptionHandler = interruptionHandler
        self.focusFilterService = focusFilterService
        self.repository = repository
        self.playerState = repository.loadPlayerState()
        self.focusSettings = repository.loadFocusModeSettings()
        self.playerState.tracks = markAvailableTracks(playerState.tracks)

        setupInterruptionHandlers()
        setupFocusFilterObserver()
        consumePendingFocusFilterActivation()
    }

    func onTimerStarted() {
        guard focusSettings.autoActivateWithTimer else { return }
        Task { await activate() }
    }

    func onTimerPaused() {
        guard isAudioPlaying else { return }
        audioEngine.fadeMasterOut(duration: 0.8) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.audioEngine.setMasterVolume(self.playerState.masterVolume * 0.3)
            }
        }
    }

    func onTimerResumed() {
        guard isActive else { return }
        audioEngine.fadeMasterIn(to: playerState.masterVolume, duration: 0.5)
    }

    func onTimerEnded() {
        Task { await deactivate() }
    }

    func onTimerReset() {
        Task { await deactivate() }
    }

    func activate(startAmbientAudio: Bool = true) async {
        guard !isActive else { return }
        isActive = true

        if startAmbientAudio && playerState.autoPlayWithTimer && !isAudioPlaying {
            startAudio(fadeIn: true, startedByFocusMode: true)
        }

        if focusSettings.enableFocusFilter {
            focusFilterService.suppressNotifications()
        }

        focusSettings.isEnabled = true
        repository.saveFocusModeSettings(focusSettings)
    }

    func deactivate() async {
        guard isActive else { return }
        isActive = false
        if audioStartedByFocusMode {
            stopAudio(fadeOut: true)
            audioStartedByFocusMode = false
        }
        focusFilterService.restoreNotifications()
        focusSettings.isEnabled = false
        repository.saveFocusModeSettings(focusSettings)
    }

    func startAudio(fadeIn: Bool = true, startedByFocusMode: Bool = false) {
        do {
            playerState.tracks = markAvailableTracks(playerState.tracks)
            try audioEngine.start(
                state: playerState,
                pauseMusicWhenAmbientPlays: focusSettings.pauseMusicWhenAmbientPlays
            )
            if fadeIn {
                audioEngine.fadeMasterIn(to: playerState.masterVolume, duration: playerState.fadeInDuration)
            }
            isAudioPlaying = true
            if startedByFocusMode {
                audioStartedByFocusMode = true
            }
            playerState.isPlaying = true
            repository.savePlayerState(playerState)
        } catch {
            isAudioPlaying = false
            playerState.isPlaying = false
            AppLogger.notify.error("AmbientAudio error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopAudio(fadeOut: Bool) {
        audioEngine.stop(fadeOut: fadeOut, duration: playerState.fadeOutDuration)
        isAudioPlaying = false
        audioStartedByFocusMode = false
        playerState.isPlaying = false
        repository.savePlayerState(playerState)
    }

    func setVolume(_ volume: Float, for sound: AmbientSound) {
        audioEngine.setVolume(volume, for: sound)
        updateTrack(sound) { $0.volume = min(max(volume, 0), 1) }
    }

    func toggleTrack(_ sound: AmbientSound) {
        updateTrack(sound) { $0.isEnabled.toggle() }
        guard let track = playerState.tracks.first(where: { $0.sound == sound }) else { return }
        if isAudioPlaying {
            audioEngine.setEnabled(track.isEnabled, sound: sound, volume: track.volume)
        }
    }

    func setMasterVolume(_ volume: Float) {
        playerState.masterVolume = min(max(volume, 0), 1)
        audioEngine.setMasterVolume(playerState.masterVolume)
        repository.savePlayerState(playerState)
    }

    func setAutoPlayWithTimer(_ enabled: Bool) {
        playerState.autoPlayWithTimer = enabled
        repository.savePlayerState(playerState)
    }

    func updateFocusSettings(_ settings: FocusModeSettings) {
        focusSettings = settings
        repository.saveFocusModeSettings(settings)
        if !settings.enableFocusFilter {
            focusFilterService.restoreNotifications()
        } else if isActive {
            focusFilterService.suppressNotifications()
        }
    }

    private func updateTrack(_ sound: AmbientSound, mutate: (inout SoundTrackState) -> Void) {
        guard let index = playerState.tracks.firstIndex(where: { $0.sound == sound }) else { return }
        mutate(&playerState.tracks[index])
        repository.savePlayerState(playerState)
    }

    private func markAvailableTracks(_ tracks: [SoundTrackState]) -> [SoundTrackState] {
        let available = audioEngine.availableSounds
        return tracks.map { track in
            var updated = track
            updated.isAvailable = available.contains(track.sound)
            if !updated.isAvailable {
                updated.isEnabled = false
            }
            return updated
        }
    }

    private func setupInterruptionHandlers() {
        interruptionHandler.onInterruptionBegan = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isAudioPlaying = false
            }
        }

        interruptionHandler.onInterruptionEnded = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                self.startAudio(fadeIn: false)
            }
        }

        interruptionHandler.onRouteChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopAudio(fadeOut: false)
            }
        }
    }

    private func setupFocusFilterObserver() {
        NotificationCenter.default
            .publisher(for: .pomodoroFocusFilterActivated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.handleFocusFilterActivation(
                    autoStart: notification.userInfo?["autoStart"] as? Bool ?? false,
                    ambient: notification.userInfo?["ambient"] as? Bool ?? true
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.consumePendingFocusFilterActivation()
            }
            .store(in: &cancellables)
    }

    private func consumePendingFocusFilterActivation() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "focus_filter_pending_activation") else { return }
        defaults.set(false, forKey: "focus_filter_pending_activation")
        handleFocusFilterActivation(
            autoStart: defaults.bool(forKey: "focus_filter_auto_start"),
            ambient: defaults.object(forKey: "focus_filter_ambient") as? Bool ?? true
        )
    }

    private func handleFocusFilterActivation(autoStart: Bool, ambient: Bool) {
        UserDefaults.standard.set(false, forKey: "focus_filter_pending_activation")
        if autoStart {
            NotificationCenter.default.post(name: .pomodoroFocusFilterAutoStartRequested, object: nil)
        }
        Task { await activate(startAmbientAudio: ambient) }
        if ambient && !isAudioPlaying {
            startAudio(fadeIn: true, startedByFocusMode: true)
        }
    }
}
