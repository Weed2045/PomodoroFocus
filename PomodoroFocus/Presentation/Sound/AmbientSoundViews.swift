import SwiftUI

struct AmbientSoundPanel: View {
    @ObservedObject var viewModel: AmbientSoundViewModel
    @State private var showFocusSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MasterControlSection(
                        isPlaying: viewModel.isPlaying,
                        masterVolume: $viewModel.masterVolume,
                        onToggle: { viewModel.togglePlayback() },
                        onVolumeChange: { viewModel.setMasterVolume($0) }
                    )

                    Divider()

                    SoundTrackGrid(
                        tracks: viewModel.tracks,
                        onToggle: { viewModel.toggleTrack($0) },
                        onVolumeChange: { sound, volume in
                            viewModel.setVolume(volume, for: sound)
                        }
                    )

                    Divider()

                    FocusModeToggleSection(
                        viewModel: viewModel,
                        onOpenSettings: { showFocusSettings = true }
                    )
                }
                .padding(20)
            }
            .background(AppTheme.ice)
            .navigationTitle(L10n.Sound.navTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showFocusSettings) {
            FocusModeSettingsView(viewModel: viewModel)
        }
    }
}

struct MasterControlSection: View {
    let isPlaying: Bool
    @Binding var masterVolume: Float
    let onToggle: () -> Void
    let onVolumeChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Sound.sectionAmbient)
                        .font(.system(size: 17, weight: .semibold))
                    Text(isPlaying ? L10n.Sound.playing : L10n.Sound.stopped)
                        .font(.system(size: 13))
                        .foregroundStyle(isPlaying ? .green : .secondary)
                }
                Spacer()
                Button(action: onToggle) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isPlaying ? .red : AppTheme.blue)
                        .frame(width: 52, height: 52)
                        .background((isPlaying ? Color.red : AppTheme.blue).opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { masterVolume },
                        set: { onVolumeChange($0) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .tint(AppTheme.blue)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct SoundTrackGrid: View {
    let tracks: [SoundTrackState]
    let onToggle: (AmbientSound) -> Void
    let onVolumeChange: (AmbientSound, Float) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Sound.sectionTracks)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(tracks) { track in
                    SoundTrackCard(
                        track: track,
                        onToggle: { onToggle(track.sound) },
                        onVolumeChange: { onVolumeChange(track.sound, $0) }
                    )
                }
            }
        }
    }
}

struct SoundTrackCard: View {
    let track: SoundTrackState
    let onToggle: () -> Void
    let onVolumeChange: (Float) -> Void
    @State private var localVolume: Float

    init(track: SoundTrackState, onToggle: @escaping () -> Void, onVolumeChange: @escaping (Float) -> Void) {
        self.track = track
        self.onToggle = onToggle
        self.onVolumeChange = onVolumeChange
        _localVolume = State(initialValue: track.volume)
    }

    private var accent: Color { Color(hex: track.sound.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: track.sound.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(track.isEnabled ? accent : .secondary)
                    .frame(width: 36, height: 36)
                    .background((track.isEnabled ? accent : Color(.systemGray4)).opacity(0.15), in: Circle())
                Spacer()
                Toggle("", isOn: Binding(get: { track.isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .tint(accent)
                    .scaleEffect(0.82)
            }

            Text(track.sound.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(track.isEnabled ? .primary : .secondary)

            if track.isEnabled {
                VStack(spacing: 6) {
                    Slider(
                        value: $localVolume,
                        in: 0...1,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                onVolumeChange(localVolume)
                            }
                        }
                    )
                    .tint(accent)

                    SoundLevelIndicator(level: localVolume, color: accent)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background((track.isEnabled ? accent.opacity(0.06) : Color.white), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(track.isEnabled ? accent.opacity(0.22) : Color.black.opacity(0.06), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: track.isEnabled)
        .onChange(of: track.volume) { _, newValue in
            localVolume = newValue
        }
    }
}

struct SoundLevelIndicator: View {
    let level: Float
    let color: Color
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = Float(index + 1) / Float(barCount)
                Capsule()
                    .fill(level >= threshold ? color : color.opacity(0.22))
                    .frame(width: 4, height: CGFloat(6 + index * 2))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FocusModeToggleSection: View {
    @ObservedObject var viewModel: AmbientSoundViewModel
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Sound.focusModeSection)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.Sound.focusModeTitle)
                            .font(.system(size: 15, weight: .semibold))
                        Text(viewModel.focusSettings.autoActivateWithTimer
                             ? L10n.Sound.focusModeSubtitleAuto
                             : L10n.Sound.focusModeSubtitleManual)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.focusSettings.autoActivateWithTimer },
                        set: { value in
                            var settings = viewModel.focusSettings
                            settings.autoActivateWithTimer = value
                            viewModel.updateSettings(settings)
                        }
                    ))
                    .labelsHidden()
                    .tint(.orange)
                }
                .padding(14)

                Divider()

                Toggle(L10n.Sound.focusModeAutoPlay, isOn: Binding(
                    get: { viewModel.autoPlayWithTimer },
                    set: { viewModel.setAutoPlayWithTimer($0) }
                ))
                .font(.system(size: 14))
                .padding(14)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

            Button(action: onOpenSettings) {
                HStack {
                    Label(L10n.Sound.focusModeSettingsButton, systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.blue)
                .padding(14)
                .background(AppTheme.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

struct FocusModeSettingsView: View {
    @ObservedObject var viewModel: AmbientSoundViewModel
    @State private var settings: FocusModeSettings = .default
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Sound.focusSettingsSectionAutomation) {
                    Toggle(L10n.Sound.focusSettingsAutoActivate, isOn: $settings.autoActivateWithTimer)
                    Toggle(L10n.Sound.focusSettingsFocusFilter, isOn: $settings.enableFocusFilter)
                    Toggle(L10n.Sound.focusSettingsPauseMusic, isOn: $settings.pauseMusicWhenAmbientPlays)
                }

                Section(L10n.Sound.focusSettingsSectionInterface) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.Sound.focusSettingsDimLabel)
                            Spacer()
                            Text("\(Int(settings.dimUILevel * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.dimUILevel, in: 0...0.85, step: 0.05)
                            .tint(.orange)
                        Text(L10n.Sound.focusSettingsDimDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(L10n.Sound.focusSettingsSectionSystem) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Sound.focusSettingsFilterTitle)
                            .font(.system(size: 15, weight: .medium))
                        Text(L10n.Sound.focusSettingsFilterDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Button(L10n.Sound.focusSettingsOpenSettings) {
                            if let url = URL(string: "App-prefs:FOCUS") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L10n.Sound.focusSettingsNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Sound.focusSettingsButtonSave) {
                        viewModel.updateSettings(settings)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Sound.focusSettingsButtonCancel) { dismiss() }
                }
            }
            .onAppear { settings = viewModel.focusSettings }
        }
    }
}
