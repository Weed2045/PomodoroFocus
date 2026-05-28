import EventKit
import SwiftUI
import UIKit

// MARK: – Main View ───────────────────────────────────────────────────────────

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var showingAddTask = false

    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                calendarCard
                daySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.ice)
        .navigationTitle(L10n.Calendar.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddTask = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.blue)
                }
                .accessibilityLabel(L10n.Calendar.addTaskAccessibility)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.Calendar.buttonToday) { viewModel.goToToday() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            ScheduleTaskSheet(selectedDate: viewModel.selectedDate) { title, duration, notes, startTime in
                viewModel.addTask(
                    title: title,
                    targetDuration: duration,
                    notes: notes,
                    startTime: startTime
                )
            }
        }
        .task {
            // Only trigger the system permission dialog when status is genuinely
            // undecided — never re-request if already denied (user must go to Settings).
            if viewModel.eventKitService.authorizationStatus == .notDetermined {
                await viewModel.requestCalendarAccess()
            }
        }
        // Re-read authorization status whenever the app returns to the foreground
        // (e.g. the user just came back from Settings after granting access).
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.refreshAfterSettingsReturn()
        }
    }

    // MARK: – Hero card
    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.monthYearString)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(viewModel.selectedDayString)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(AppTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: AppTheme.blue.opacity(0.35), radius: 12, x: 0, y: 6)

            Image(systemName: "calendar")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.10))
                .padding(.top, 6)
                .padding(.trailing, 12)
                .allowsHitTesting(false)
        }
    }

    // MARK: – Calendar card
    private var calendarCard: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.navigateMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.ice, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(viewModel.monthYearString)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.navy)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.navigateMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.ice, in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Weekday header
            HStack(spacing: 0) {
                ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { d in
                    Text(d)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            // Call once and bind to a local let to avoid double computation per cell.
            let gridDates = viewModel.datesInDisplayedMonth()
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gridDates.indices, id: \.self) { i in
                    if let date = gridDates[i] {
                        DayCell(
                            date: date,
                            isSelected: viewModel.isSelected(date),
                            isToday: viewModel.isToday(date),
                            hasTask: viewModel.hasTasks(on: date),
                            isDimmed: !viewModel.isInDisplayedMonth(date)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28)) {
                                viewModel.selectDate(date)
                            }
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: – Day content
    private var daySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // iPhone Calendar events
            iPhoneCalendarSection

            // Planned Pomodoro tasks
            plannedTasksSection
        }
    }

    @ViewBuilder
    private var iPhoneCalendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.Calendar.sectionIphoneCalendar, icon: "calendar", color: AppTheme.sky)

            if viewModel.eventKitService.isAuthorized {
                if viewModel.calendarEvents.isEmpty {
                    emptyCard(L10n.Calendar.eventsEmpty)
                } else {
                    VStack(spacing: 8) {
                        // eventIdentifier is implicitly-unwrapped String — use index to avoid nil crash
                        ForEach(Array(viewModel.calendarEvents.enumerated()), id: \.offset) { _, event in
                            CalendarEventCard(event: event)
                        }
                    }
                }
            } else {
                calendarPermissionCard
            }
        }
    }

    @ViewBuilder
    private var plannedTasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(L10n.Calendar.sectionPlannedTasks, icon: "checkmark.circle", color: AppTheme.blue)
                Spacer()
                Button {
                    showingAddTask = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.Common.new)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.blue, in: Capsule())
                }
            }

            if viewModel.scheduledTasks.isEmpty {
                emptyCard(L10n.Calendar.tasksEmpty)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.scheduledTasks) { task in
                        ScheduledTaskCard(
                            task: task,
                            onToggleComplete: { viewModel.toggleComplete(task: task) },
                            onDelete: { viewModel.deleteTask(id: task.id) }
                        )
                    }
                }
            }
        }
    }

    private var calendarPermissionCard: some View {
        let isDenied = viewModel.eventKitService.authorizationStatus == .denied
        return VStack(spacing: 12) {
            Image(systemName: isDenied ? "calendar.badge.exclamationmark" : "calendar.badge.plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.sky)
            Text(isDenied ? L10n.Calendar.permissionDeniedTitle : L10n.Calendar.permissionNeededTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
            Text(
                isDenied
                    ? L10n.Calendar.permissionDeniedMessage
                    : L10n.Calendar.permissionNeededMessage
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                if isDenied {
                    // Already denied – send user to iOS Settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task { await viewModel.requestCalendarAccess() }
                }
            } label: {
                Text(isDenied ? L10n.Calendar.permissionButtonSettings : L10n.Calendar.permissionButtonGrant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(AppTheme.blue, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: – Day Cell ────────────────────────────────────────────────────────────

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasTask: Bool
    let isDimmed: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(AppTheme.heroGradient)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .strokeBorder(AppTheme.blue, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                Text(dayNumber)
                    .font(.system(
                        size: 14,
                        weight: (isToday || isSelected) ? .bold : .regular,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday    ? AppTheme.blue :
                        isDimmed   ? Color(.systemGray3) :
                                     AppTheme.navy
                    )
            }
            .frame(width: 36, height: 36)

            // Task indicator dot
            Circle()
                .fill(
                    hasTask
                    ? (isSelected ? Color.white.opacity(0.75) : AppTheme.sky)
                    : Color.clear
                )
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – iPhone Calendar Event Card ─────────────────────────────────────────

private struct CalendarEventCard: View {
    let event: EKEvent

    private var timeLabel: String {
        guard let start = event.startDate else { return "" }
        if event.isAllDay { return L10n.Calendar.eventAllDay }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let end = event.endDate.map { " – " + fmt.string(from: $0) } ?? ""
        return fmt.string(from: start) + end
    }

    private var calendarColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Calendar colour accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled event")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !timeLabel.isEmpty {
                        Label(timeLabel, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let cal = event.calendar {
                        Text(cal.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: – Scheduled Task Card ─────────────────────────────────────────────────

private struct ScheduledTaskCard: View {
    let task: ScheduledTask
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    private var timeLabel: String? {
        guard let t = task.startTime else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: t)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button { onToggleComplete() } label: {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? AppTheme.teal : Color(.systemGray4))
                        .frame(width: 28, height: 28)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? .secondary : AppTheme.navy)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if let t = timeLabel {
                        Label(t, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label("\(Int(task.targetDuration / 60))m focus", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Menu {
                Button(L10n.Common.delete, role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray6), in: Circle())
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: – Schedule Task Sheet ─────────────────────────────────────────────────

struct ScheduleTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetMinutes = 25
    @State private var notes = ""
    @State private var hasStartTime = false
    @State private var startTime: Date
    @FocusState private var titleFocused: Bool

    let selectedDate: Date
    let onAdd: (String, TimeInterval, String, Date?) -> Void

    private let presets = [5, 10, 15, 25, 30, 45, 60, 90]

    init(selectedDate: Date, onAdd: @escaping (String, TimeInterval, String, Date?) -> Void) {
        self.selectedDate = selectedDate
        self.onAdd = onAdd
        // Default start time = 9:00 on selectedDate
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        comps.hour = 9; comps.minute = 0
        _startTime = State(initialValue: Calendar.current.date(from: comps) ?? selectedDate)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        return selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Header ─────────────────────────────────────────
                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(L10n.Calendar.scheduleHeaderTitle)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text(L10n.Calendar.scheduleHeaderSubtitle(dateLabel))
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(AppTheme.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: AppTheme.blue.opacity(0.35), radius: 12, x: 0, y: 6)

                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 68, weight: .ultraLight))
                            .foregroundStyle(Color.white.opacity(0.10))
                            .padding(.top, 6).padding(.trailing, 14)
                            .allowsHitTesting(false)
                    }

                    // ── Title ──────────────────────────────────────────
                    fieldSection(label: L10n.Calendar.scheduleFieldTitle, icon: "text.cursor") {
                        TextField(L10n.Calendar.scheduleFieldTitlePlaceholder, text: $title)
                            .focused($titleFocused)
                            .font(.body)
                            .foregroundStyle(AppTheme.navy)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // ── Duration ───────────────────────────────────────
                    fieldSection(label: L10n.Calendar.scheduleFieldDuration, icon: "clock") {
                        durationPicker
                    }

                    // ── Start time ─────────────────────────────────────
                    fieldSection(label: L10n.Calendar.scheduleFieldStartTime, icon: "alarm") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $hasStartTime.animation()) {
                                Text(L10n.Calendar.scheduleFieldStartTimeToggle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.navy)
                            }
                            .tint(AppTheme.blue)
                            .padding(.horizontal, 14)

                            if hasStartTime {
                                Divider().padding(.horizontal, 14)
                                DatePicker(
                                    "Start",
                                    selection: $startTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // ── Notes ──────────────────────────────────────────
                    fieldSection(label: L10n.Calendar.scheduleFieldNotes, icon: "note.text") {
                        TextField(L10n.Calendar.scheduleFieldNotesPlaceholder, text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.body)
                            .foregroundStyle(AppTheme.navy)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            // ── Action buttons ─────────────────────────────────────────
            VStack(spacing: 10) {
                Button {
                    onAdd(title, TimeInterval(targetMinutes * 60), notes, hasStartTime ? startTime : nil)
                    dismiss()
                } label: {
                    Text(L10n.Calendar.scheduleButtonAdd)
                        .fontWeight(.semibold)
                }
                .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)

                Button { dismiss() } label: {
                    Text(L10n.Calendar.scheduleButtonCancel)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.ice.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4))
        }
        .background(AppTheme.ice.ignoresSafeArea())
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .onAppear { titleFocused = true }
    }

    // MARK: – Duration picker
    private var durationPicker: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { p in
                        let active = targetMinutes == p
                        Button {
                            withAnimation(.spring(response: 0.25)) { targetMinutes = p }
                        } label: {
                            Text("\(p)m")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(active ? .white : AppTheme.blue)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(active ? AppTheme.blue : AppTheme.blue.opacity(0.10), in: Capsule())
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

    // MARK: – Field wrapper
    private func fieldSection<C: View>(
        label: String, icon: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
            }
            content()
        }
    }
}
