import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var soundViewModel: AmbientSoundViewModel
    /// Prevents double-save when the user taps the Save button then navigates back.
    @State private var savedExplicitly = false
    @State private var showSoundPanel = false

    init(viewModel: SettingsViewModel, soundViewModel: AmbientSoundViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.soundViewModel = soundViewModel
    }

    var body: some View {
        Form {
            Section(L10n.Settings.sectionDurations) {
                Stepper(value: $viewModel.focusMinutes, in: 1...180) {
                    settingRow(title: L10n.Settings.focus,
                               value: "\(viewModel.focusMinutes)m",
                               tint: AppTheme.blue)
                }
                Stepper(value: $viewModel.shortBreakMinutes, in: 1...60) {
                    settingRow(title: L10n.Settings.shortBreak,
                               value: "\(viewModel.shortBreakMinutes)m",
                               tint: AppTheme.sky)
                }
                Stepper(value: $viewModel.longBreakMinutes, in: 1...120) {
                    settingRow(title: L10n.Settings.longBreak,
                               value: "\(viewModel.longBreakMinutes)m",
                               tint: AppTheme.teal)
                }
            }

            Section(L10n.Settings.sectionCycle) {
                Stepper(value: $viewModel.sessionsBeforeLongBreak, in: 1...12) {
                    settingRow(
                        title: L10n.Settings.longBreakAfter,
                        value: L10n.Settings.sessionsCount(viewModel.sessionsBeforeLongBreak),
                        tint: AppTheme.navy
                    )
                }
            }

            Section("Focus") {
                Button {
                    showSoundPanel = true
                } label: {
                    HStack {
                        Label("Âm thanh & Focus", systemImage: "waveform.circle.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(AppTheme.blue)
            }

            Section {
                Button {
                    viewModel.restoreDefaults()
                } label: {
                    Label(L10n.Settings.restoreDefaults, systemImage: "arrow.counterclockwise")
                        .foregroundStyle(AppTheme.blue)
                }
            }
        }
        .navigationTitle(L10n.Settings.navTitle)
        .tint(AppTheme.blue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Settings.buttonSave) {
                    viewModel.save()
                    savedExplicitly = true
                }
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.blue)
            }
        }
        .sheet(isPresented: $showSoundPanel) {
            AmbientSoundPanel(viewModel: soundViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Auto-save on back-navigation only when the user didn't already tap Save.
        .onDisappear {
            if !savedExplicitly { viewModel.save() }
            savedExplicitly = false
        }
    }

    private func settingRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(tint)
                .frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(tint)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
