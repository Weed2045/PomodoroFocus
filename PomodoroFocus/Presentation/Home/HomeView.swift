import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Binding private var path: NavigationPath

    @State private var showingAddTask = false
    @State private var editingTask: PomodoroTask?

    init(viewModel: HomeViewModel, path: Binding<NavigationPath>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _path = path
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                settingsSummary
                progressSummary
                taskSummary
                gamificationSummary
                actions
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .background(AppTheme.ice)
        .navigationTitle(L10n.Tab.focus)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path.append(AppRoute.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(AppTheme.blue)
                }
                .accessibilityLabel(L10n.Common.settings)
            }
        }
        .onAppear { viewModel.refresh() }
        // Add task popup
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet { title, duration, notes in
                viewModel.createTask(title: title, targetDuration: duration, notes: notes)
            }
        }
        // Edit task popup
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task) { title, duration, notes in
                viewModel.updateTask(
                    id: task.id,
                    title: title,
                    targetDuration: duration,
                    notes: notes
                )
            }
        }
    }

    // MARK: – Header hero card
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Home.headerTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(
                    viewModel.activeSessionTitle.map { L10n.Home.currentSession($0) }
                    ?? L10n.Home.headerSubtitle
                )
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(AppTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: AppTheme.blue.opacity(0.38), radius: 14, x: 0, y: 7)

            Image(systemName: "timer")
                .font(.system(size: 76, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.10))
                .padding(.top, 8)
                .padding(.trailing, 12)
                .allowsHitTesting(false)
        }
    }

    // MARK: – Settings summary
    private var settingsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.Home.sectionSettings)
            HStack(spacing: 10) {
                MetricTile(title: L10n.Home.settingsFocus,
                           value: viewModel.settings.focusDuration.minutesText,
                           tint: AppTheme.blue)
                MetricTile(title: L10n.Home.settingsBreak,
                           value: viewModel.settings.shortBreakDuration.minutesText,
                           tint: AppTheme.sky)
                MetricTile(title: L10n.Home.settingsLong,
                           value: viewModel.settings.longBreakDuration.minutesText,
                           tint: AppTheme.teal)
            }
            MetricTile(
                title: L10n.Home.settingsLongBreakEvery,
                value: L10n.Home.settingsSessionsCount(viewModel.settings.sessionsBeforeLongBreak),
                tint: AppTheme.navy
            )
        }
    }

    // MARK: – Today progress
    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.Home.sectionToday)
            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.completedSessionsToday)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.navy)
                        Text(L10n.Home.todaySessionsCompleted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(AppTheme.blue.opacity(0.10))
                            .frame(width: 58, height: 58)
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AppTheme.sky)
                    Text(viewModel.totalFocusTimeToday.focusTimeText)
                        .font(.headline)
                        .foregroundStyle(AppTheme.navy)
                    Spacer()
                    Text(L10n.Home.todayTotalTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: – Tasks
    private var taskSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(L10n.Home.sectionTasks)
                Spacer()
                Button {
                    showingAddTask = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.Common.new)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.blue, in: Capsule())
                }
                .accessibilityLabel(L10n.TaskForm.buttonAdd)
            }

            if viewModel.tasks.isEmpty {
                emptyTasksPlaceholder
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private var emptyTasksPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.blue.opacity(0.4))
            Text(L10n.Home.taskEmptyTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(L10n.Home.taskEmptySubtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: – Gamification
    private var gamificationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.Home.sectionProgress)
            HStack(spacing: 10) {
                MetricTile(title: L10n.Home.gamificationStreak,
                           value: "\(viewModel.gamificationSummary.streakDays)d",
                           tint: AppTheme.blue)
                MetricTile(title: L10n.Home.gamificationBadges,
                           value: "\(viewModel.gamificationSummary.unlockedAchievements.count)/2",
                           tint: AppTheme.sky)
            }
            if !viewModel.gamificationSummary.unlockedAchievements.isEmpty {
                HStack(spacing: 8) {
                    ForEach(viewModel.gamificationSummary.unlockedAchievements) { achievement in
                        Label(achievement.title, systemImage: "medal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.blue.opacity(0.10), in: Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: – Actions
    private var actions: some View {
        VStack(spacing: 10) {
            Button { path.append(AppRoute.timer) } label: {
                Label(L10n.Home.actionStartPomodoro, systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))

            Button { path.append(AppRoute.settings) } label: {
                Label(L10n.Home.actionSettings, systemImage: "slider.horizontal.3")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: – Task row
    private func taskRow(_ task: PomodoroTask) -> some View {
        let isSelected = viewModel.selectedTaskID == task.id

        return HStack(spacing: 12) {

            // ── Status indicator ──────────────────────────────────────────
            Button {
                guard !task.isCompleted else { return }
                viewModel.selectTask(id: isSelected ? nil : task.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(indicatorColor(task: task, isSelected: isSelected))
                        .frame(width: 28, height: 28)
                    Image(systemName: task.isCompleted ? "checkmark" : (isSelected ? "checkmark" : ""))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(task.isCompleted)

            // ── Info ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? .secondary : AppTheme.navy)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .lineLimit(1)

                    if task.isCompleted {
                        Text(L10n.Home.taskStatusDone)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.teal.opacity(0.14), in: Capsule())
                    }

                    if task.notes.contains("Source document:") {
                        Text(L10n.Home.taskFromScan)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.blue.opacity(0.12), in: Capsule())
                    }
                }

                // Progress bar + stats
                VStack(alignment: .leading, spacing: 3) {
                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(task.isCompleted ? AppTheme.teal : AppTheme.blue)
                                .frame(width: geo.size.width * task.progressFraction, height: 3)
                        }
                    }
                    .frame(height: 3)

                    Text(progressLabel(task))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // ── Menu ──────────────────────────────────────────────────────
            Menu {
                Button {
                    editingTask = task
                } label: {
                    Label(L10n.Common.edit, systemImage: "pencil")
                }
                Button(L10n.Common.delete, role: .destructive) {
                    viewModel.deleteTask(id: task.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray6), in: Circle())
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: – Helpers
    private func indicatorColor(task: PomodoroTask, isSelected: Bool) -> Color {
        if task.isCompleted { return AppTheme.teal }
        if isSelected       { return AppTheme.blue }
        return Color(.systemGray4)
    }

    private func progressLabel(_ task: PomodoroTask) -> String {
        let done = Int(task.totalFocusTime / 60)
        let target = Int(task.targetDuration / 60)
        let sessions = task.completedSessions
        return L10n.Home.taskProgress(done: done, target: target, sessions: sessions)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.navy)
    }
}

// MARK: – Add Task Sheet ─────────────────────────────────────────────────────

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetMinutes = 25
    @State private var notes = ""
    @FocusState private var titleFocused: Bool

    let onAdd: (String, TimeInterval, String) -> Void

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TaskFormSheet(
            headerIcon: "target",
            headerTitle: L10n.TaskForm.addTitle,
            headerSubtitle: L10n.TaskForm.addSubtitle,
            title: $title,
            targetMinutes: $targetMinutes,
            notes: $notes,
            titleFocused: $titleFocused,
            progressTask: nil,
            primaryLabel: L10n.TaskForm.buttonAdd,
            canSubmit: canSubmit
        ) {
            onAdd(title, TimeInterval(targetMinutes * 60), notes)
            dismiss()
        } onCancel: {
            dismiss()
        }
        .onAppear { titleFocused = true }
    }
}

// MARK: – Edit Task Sheet ────────────────────────────────────────────────────

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var targetMinutes: Int
    @State private var notes: String
    @FocusState private var titleFocused: Bool

    let task: PomodoroTask
    let onSave: (String, TimeInterval, String) -> Void

    init(task: PomodoroTask, onSave: @escaping (String, TimeInterval, String) -> Void) {
        self.task = task
        self.onSave = onSave
        _title         = State(initialValue: task.title)
        _targetMinutes = State(initialValue: max(Int(task.targetDuration / 60), 5))
        _notes         = State(initialValue: task.notes)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TaskFormSheet(
            headerIcon: "pencil.and.list.clipboard",
            headerTitle: L10n.TaskForm.editTitle,
            headerSubtitle: task.isCompleted ? L10n.TaskForm.editCompletedSubtitle : L10n.TaskForm.editSubtitle,
            title: $title,
            targetMinutes: $targetMinutes,
            notes: $notes,
            titleFocused: $titleFocused,
            progressTask: task,
            primaryLabel: L10n.TaskForm.buttonSave,
            canSubmit: canSubmit
        ) {
            onSave(title, TimeInterval(targetMinutes * 60), notes)
            dismiss()
        } onCancel: {
            dismiss()
        }
    }
}

// MARK: – Shared Custom Form Sheet ───────────────────────────────────────────
// A fully custom bottom-sheet that matches the Home screen's blue/white design.

private struct TaskFormSheet: View {
    // Config
    let headerIcon: String
    let headerTitle: String
    let headerSubtitle: String
    @Binding var title: String
    @Binding var targetMinutes: Int
    @Binding var notes: String
    var titleFocused: FocusState<Bool>.Binding
    let progressTask: PomodoroTask?   // non-nil when editing
    let primaryLabel: String
    let canSubmit: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    // Preset minute chips
    private let presets = [5, 10, 15, 25, 30, 45, 60, 90]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 20) {
                    // ── Hero header ─────────────────────────────────
                    headerCard

                    // ── Title field ─────────────────────────────────
                    fieldSection(label: L10n.TaskForm.fieldTitle, systemImage: "text.cursor") {
                        TextField(L10n.TaskForm.fieldTitlePlaceholder, text: $title)
                            .focused(titleFocused)
                            .font(.body)
                            .foregroundStyle(AppTheme.navy)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // ── Duration picker ─────────────────────────────
                    fieldSection(label: L10n.TaskForm.fieldDuration, systemImage: "clock") {
                        durationPicker
                    }

                    // ── Notes field ─────────────────────────────────
                    fieldSection(label: L10n.TaskForm.fieldNotes, systemImage: "note.text") {
                        TextField(L10n.TaskForm.fieldNotesPlaceholder,
                                  text: $notes,
                                  axis: .vertical)
                            .lineLimit(3...6)
                            .font(.body)
                            .foregroundStyle(AppTheme.navy)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // ── Progress card (edit only) ───────────────────
                    if let task = progressTask {
                        progressCard(task)
                    }

                    // Bottom padding so content isn't hidden under buttons
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .scrollDismissesKeyboard(.interactively)

            // ── Fixed action buttons ────────────────────────────────
            actionButtons
        }
        .background(AppTheme.ice.ignoresSafeArea())
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    // MARK: – Header card
    private var headerCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: headerIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(headerTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: AppTheme.blue.opacity(0.35), radius: 12, x: 0, y: 6)

            // Watermark
            Image(systemName: headerIcon)
                .font(.system(size: 68, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.10))
                .padding(.top, 6)
                .padding(.trailing, 14)
                .allowsHitTesting(false)
        }
    }

    // MARK: – Duration picker
    private var durationPicker: some View {
        VStack(spacing: 14) {
            // Large value + ± controls
            HStack(spacing: 0) {
                // Minus
                Button {
                    if targetMinutes > 5 { targetMinutes -= 5 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(targetMinutes > 5 ? AppTheme.blue : Color(.systemGray3))
                        .frame(width: 48, height: 48)
                        .background(AppTheme.ice, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Number display
                VStack(spacing: 2) {
                    Text("\(targetMinutes)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.navy)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: targetMinutes)
                    Text(L10n.TaskForm.durationMinutes)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Plus
                Button {
                    if targetMinutes < 180 { targetMinutes += 5 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(targetMinutes < 180 ? .white : Color(.systemGray3))
                        .frame(width: 48, height: 48)
                        .background(targetMinutes < 180 ? AppTheme.blue : Color(.systemGray5), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            Divider()

            // Quick-select chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        let isActive = targetMinutes == preset
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                targetMinutes = preset
                            }
                        } label: {
                            Text("\(preset)m")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isActive ? .white : AppTheme.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isActive ? AppTheme.blue : AppTheme.blue.opacity(0.10),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    // MARK: – Progress card (edit mode)
    private func progressCard(_ task: PomodoroTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label row
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.seal.fill" : "chart.bar.fill")
                    .foregroundStyle(task.isCompleted ? AppTheme.teal : AppTheme.blue)
                Text(task.isCompleted ? L10n.TaskForm.progressCompleted : L10n.TaskForm.progressTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                if task.isCompleted {
                    Text(L10n.Common.done)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.teal.opacity(0.14), in: Capsule())
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: task.isCompleted
                                    ? [AppTheme.teal, AppTheme.sky]
                                    : [AppTheme.blue, AppTheme.sky],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * task.progressFraction, height: 7)
                }
            }
            .frame(height: 7)

            // Stats row
            HStack(spacing: 16) {
                statPill(
                    icon: "clock.fill",
                    value: "\(Int(task.totalFocusTime / 60))m",
                    label: L10n.TaskForm.progressFocused,
                    color: AppTheme.blue
                )
                statPill(
                    icon: "target",
                    value: "\(Int(task.targetDuration / 60))m",
                    label: L10n.TaskForm.progressGoal,
                    color: AppTheme.navy
                )
                statPill(
                    icon: "checkmark.circle.fill",
                    value: "\(task.completedSessions)",
                    label: L10n.TaskForm.progressSessions(task.completedSessions),
                    color: AppTheme.sky
                )
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.navy)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Field section wrapper
    private func fieldSection<Content: View>(
        label: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
            }
            content()
        }
    }

    // MARK: – Action buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onSubmit()
            } label: {
                Text(primaryLabel)
                    .fontWeight(.semibold)
            }
            .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            Button {
                onCancel()
            } label: {
                Text(L10n.TaskForm.buttonCancel)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            AppTheme.ice
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4)
        )
    }
}
