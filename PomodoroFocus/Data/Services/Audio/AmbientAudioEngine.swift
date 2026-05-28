import AVFoundation
import Foundation

@MainActor
final class AmbientAudioEngine {
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private var tracks: [AmbientSound: TrackNode] = [:]
    private var fadeTimers: [AmbientSound: Timer] = [:]
    private var masterFadeTimer: Timer?
    private var playbackGeneration = 0

    private struct TrackNode {
        let player: AVAudioPlayerNode
        let mixer: AVAudioMixerNode
        let buffer: AVAudioPCMBuffer
    }

    init() {
        setupEngine()
    }

    var availableSounds: Set<AmbientSound> {
        Set(tracks.keys)
    }

    func start(state: AmbientPlayerState, pauseMusicWhenAmbientPlays: Bool) throws {
        playbackGeneration += 1
        masterFadeTimer?.invalidate()
        masterFadeTimer = nil
        try setupAudioSession(pauseMusicWhenAmbientPlays: pauseMusicWhenAmbientPlays)
        if !engine.isRunning {
            try engine.start()
        }
        masterMixer.outputVolume = state.masterVolume

        for trackState in state.tracks where trackState.isEnabled && trackState.isAvailable {
            startTrack(trackState.sound, volume: trackState.volume)
        }
    }

    func stop(fadeOut: Bool, duration: Double = 2.0) {
        playbackGeneration += 1
        let generation = playbackGeneration
        if fadeOut {
            fadeMaster(to: 0, duration: duration) { [weak self] in
                guard let self, self.playbackGeneration == generation else { return }
                self.stopAllPlayers()
                self.engine.stop()
                self.deactivateAudioSession()
            }
        } else {
            stopAllPlayers()
            engine.stop()
            deactivateAudioSession()
        }
    }

    func setVolume(_ volume: Float, for sound: AmbientSound) {
        tracks[sound]?.mixer.outputVolume = clamped(volume)
    }

    func setEnabled(_ enabled: Bool, sound: AmbientSound, volume: Float) {
        guard let track = tracks[sound] else { return }
        if enabled {
            if !engine.isRunning {
                try? setupAudioSession(pauseMusicWhenAmbientPlays: false)
                try? engine.start()
            }
            if !track.player.isPlaying {
                scheduleLoop(track.player, buffer: track.buffer)
            }
            fadeTrack(sound, to: clamped(volume), duration: 0.5)
        } else {
            fadeTrack(sound, to: 0, duration: 0.5) { [weak self] in
                self?.tracks[sound]?.player.stop()
            }
        }
    }

    func setMasterVolume(_ volume: Float) {
        masterMixer.outputVolume = clamped(volume)
    }

    func fadeMasterIn(to target: Float, duration: Double) {
        masterMixer.outputVolume = 0
        fadeMaster(to: clamped(target), duration: duration)
    }

    func fadeMasterOut(duration: Double, completion: (() -> Void)? = nil) {
        fadeMaster(to: 0, duration: duration, completion: completion)
    }

    private func setupEngine() {
        engine.attach(masterMixer)
        engine.connect(
            masterMixer,
            to: engine.mainMixerNode,
            format: engine.mainMixerNode.outputFormat(forBus: 0)
        )

        for sound in AmbientSound.allCases {
            guard let node = makeTrackNode(for: sound) else { continue }
            tracks[sound] = node
            engine.attach(node.player)
            engine.attach(node.mixer)
            engine.connect(node.player, to: node.mixer, format: node.buffer.format)
            engine.connect(node.mixer, to: masterMixer, format: node.buffer.format)
        }
    }

    private func makeTrackNode(for sound: AmbientSound) -> TrackNode? {
        let buffer: AVAudioPCMBuffer?
        if
            let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension),
            let file = try? AVAudioFile(forReading: url),
            let loaded = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ),
            (try? file.read(into: loaded)) != nil
        {
            buffer = loaded
        } else {
            #if DEBUG
            buffer = Self.makeDebugBuffer(for: sound)
            #else
            buffer = nil
            #endif
        }

        guard let buffer else {
            AppLogger.notify.warning("AmbientAudioEngine missing asset \(sound.rawValue, privacy: .public).m4a")
            return nil
        }

        let player = AVAudioPlayerNode()
        let mixer = AVAudioMixerNode()
        mixer.outputVolume = 0
        return TrackNode(player: player, mixer: mixer, buffer: buffer)
    }

    private func startTrack(_ sound: AmbientSound, volume: Float) {
        guard let track = tracks[sound] else { return }
        if !track.player.isPlaying {
            scheduleLoop(track.player, buffer: track.buffer)
        }
        fadeTrack(sound, to: clamped(volume), duration: 0.8)
    }

    private func scheduleLoop(_ player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer) {
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    private func stopAllPlayers() {
        fadeTimers.values.forEach { $0.invalidate() }
        fadeTimers.removeAll()
        masterFadeTimer?.invalidate()
        masterFadeTimer = nil
        tracks.values.forEach { node in
            node.mixer.outputVolume = 0
            node.player.stop()
        }
    }

    private func fadeTrack(
        _ sound: AmbientSound,
        to target: Float,
        duration: Double,
        completion: (() -> Void)? = nil
    ) {
        fadeTimers[sound]?.invalidate()
        guard let track = tracks[sound] else { return }
        runFade(
            duration: duration,
            start: track.mixer.outputVolume,
            target: target,
            update: { track.mixer.outputVolume = $0 },
            completion: completion,
            store: { [weak self] timer in self?.fadeTimers[sound] = timer },
            clear: { [weak self] in self?.fadeTimers[sound] = nil }
        )
    }

    private func fadeMaster(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        masterFadeTimer?.invalidate()
        runFade(
            duration: duration,
            start: masterMixer.outputVolume,
            target: target,
            update: { [weak self] in self?.masterMixer.outputVolume = $0 },
            completion: completion,
            store: { [weak self] timer in self?.masterFadeTimer = timer },
            clear: { [weak self] in self?.masterFadeTimer = nil }
        )
    }

    private func runFade(
        duration: Double,
        start: Float,
        target: Float,
        update: @escaping (Float) -> Void,
        completion: (() -> Void)?,
        store: @escaping (Timer) -> Void,
        clear: @escaping () -> Void
    ) {
        guard duration > 0 else {
            update(target)
            completion?()
            return
        }

        let fps = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        let steps = max(1, Int(duration * Double(fps)))
        let delta = (target - start) / Float(steps)
        var current = 0

        let timer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { timer in
            current += 1
            update(current >= steps ? target : start + delta * Float(current))
            if current >= steps {
                timer.invalidate()
                clear()
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        store(timer)
    }

    private func setupAudioSession(pauseMusicWhenAmbientPlays: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.allowAirPlay, .allowBluetoothA2DP]
        if pauseMusicWhenAmbientPlays {
            options = [.allowAirPlay, .allowBluetoothA2DP]
        } else {
            options.formUnion([.mixWithOthers, .duckOthers])
        }
        try session.setCategory(.playback, mode: .default, options: options)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    #if DEBUG
    private static func makeDebugBuffer(for sound: AmbientSound) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let duration = 3.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        var seed: UInt32 = UInt32(abs(sound.rawValue.hashValue % 65_535))

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let value: Float
            switch sound {
            case .rain:
                value = filteredNoise(seed: &seed, scale: 0.08)
            case .cafe:
                value = Float(sin(2 * Double.pi * 220 * t)) * 0.025 + filteredNoise(seed: &seed, scale: 0.035)
            case .forest:
                value = Float(sin(2 * Double.pi * 660 * t) + sin(2 * Double.pi * 880 * t)) * 0.018 + filteredNoise(seed: &seed, scale: 0.025)
            case .whiteNoise:
                value = filteredNoise(seed: &seed, scale: 0.12)
            }
            channel[frame] = value
        }
        return buffer
    }

    private static func filteredNoise(seed: inout UInt32, scale: Float) -> Float {
        seed = 1_664_525 &* seed &+ 1_013_904_223
        let normalized = Float(seed) / Float(UInt32.max)
        return (normalized * 2 - 1) * scale
    }
    #endif
}
