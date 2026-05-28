import SwiftUI

struct TimerView: View {
    @StateObject private var viewModel: TimerViewModel
    @ObservedObject private var soundViewModel: AmbientSoundViewModel
    @State private var showSoundPanel = false

    init(viewModel: TimerViewModel, soundViewModel: AmbientSoundViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.soundViewModel = soundViewModel
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            sessionHeader
            taskPicker

            // Circular ring + time display
            // aspectRatio(1) ensures the ZStack is always a perfect square so the
            // ring diameter matches its width and the text is proportionate.
            ZStack {
                CircularProgressView(configuration: viewModel.progressConfiguration) {
                    viewModel.progressAnimationCompleted()
                }

                VStack(spacing: 6) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(viewModel.progressConfiguration.remaining(at: timeline.date).clockText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.4)
                            .foregroundStyle(AppTheme.navy)
                    }
                    Text(viewModel.status.displayText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 280)
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 24)

            // Sessions-today badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.sky)
                Text(L10n.Timer.completedToday(viewModel.completedSessionsToday))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            Spacer(minLength: 8)
            controls
        }
        .padding(24)
        .background(AppTheme.ice)
        .navigationTitle(L10n.Timer.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSoundPanel = true
                } label: {
                    Image(systemName: soundViewModel.isPlaying ? "waveform.circle.fill" : "waveform.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22))
                        .foregroundStyle(soundViewModel.isPlaying ? AppTheme.blue : .secondary)
                }
                .accessibilityLabel("Âm thanh & Focus")
            }
        }
        .sheet(isPresented: $showSoundPanel) {
            AmbientSoundPanel(viewModel: soundViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: – Session header
    private var sessionHeader: some View {
        VStack(spacing: 8) {
            Text(viewModel.sessionType.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(viewModel.sessionType.tint)

            Text(viewModel.sessionType == .focus
                 ? L10n.Timer.sessionStay
                 : L10n.Timer.sessionRest)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: – Task picker card
    private var taskPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.Timer.activeTaskLabel, systemImage: "target")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.blue)

            Picker(L10n.Timer.activeTaskLabel, selection: Binding(
                get: { viewModel.selectedTaskID },
                set: { viewModel.selectTask(id: $0) }
            )) {
                Text(L10n.Timer.activeTaskNone).tag(UUID?.none)
                ForEach(viewModel.tasks) { task in
                    Text(task.title).tag(Optional(task.id))
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.status == .running || viewModel.status == .paused)

            Text(viewModel.activeTaskTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.navy)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    // MARK: – Controls
    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.primaryAction()
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: viewModel.primaryActionIcon)
            }
            .buttonStyle(PrimaryButtonStyle(tint: viewModel.sessionType.tint))

            Button {
                viewModel.reset()
            } label: {
                Label(L10n.Timer.actionReset, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

private extension TimerStatus {
    var displayText: String {
        switch self {
        case .idle:      L10n.Timer.statusReady
        case .running:   L10n.Timer.statusRunning
        case .paused:    L10n.Timer.statusPaused
        case .completed: L10n.Timer.statusComplete
        }
    }
}
