import SwiftUI
import WidgetKit

// MARK: - Theme constants (mirrors AppTheme — hex-only, no main-target dependency)
private enum WT {
    static let navy  = Color(red: 0.06, green: 0.15, blue: 0.42)
    static let blue  = Color(red: 0.16, green: 0.44, blue: 0.96)
    static let sky   = Color(red: 0.35, green: 0.67, blue: 1.00)
    static let ice   = Color(red: 0.93, green: 0.96, blue: 1.00)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [navy, blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Timeline

struct PomodoroFocusWidgetEntry: TimelineEntry {
    let date: Date
}

struct PomodoroFocusWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroFocusWidgetEntry {
        PomodoroFocusWidgetEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (PomodoroFocusWidgetEntry) -> Void) {
        completion(PomodoroFocusWidgetEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroFocusWidgetEntry>) -> Void) {
        completion(Timeline(entries: [PomodoroFocusWidgetEntry(date: Date())],
                            policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Widget

struct PomodoroFocusWidget: Widget {
    private let kind = "PomodoroFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroFocusWidgetProvider()) { entry in
            PomodoroFocusWidgetView(entry: entry)
        }
        .configurationDisplayName("PomodoroFocus")
        .description("Quick glance at your focus session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Dispatch

private struct PomodoroFocusWidgetView: View {
    let entry: PomodoroFocusWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView()
        default:            SmallWidgetView()
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Gradient backdrop
            WT.heroGradient
                .ignoresSafeArea()

            // Decorative circle
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 90, height: 90)
                .offset(x: 50, y: -20)

            VStack(alignment: .leading, spacing: 0) {
                // Icon
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // App name
                Text("Pomodoro\nFocus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(1)

                Spacer().frame(height: 6)

                // CTA
                Text(L10n.Home.actionStartPomodoro)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WT.sky)
            }
            .padding(14)
        }
        .widgetBackground(WT.heroGradient)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    private let sessions: [(emoji: String, label: String, minutes: Int, color: Color)] = [
        ("🍅", L10n.Session.focus,      25, Color(hex: "#FF6B6B")),
        ("☕", L10n.Session.shortBreak,  5, Color(hex: "#5CDB95")),
        ("🌙", L10n.Session.longBreak,  15, Color(hex: "#74B9FF"))
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full gradient background
            WT.heroGradient
                .ignoresSafeArea()

            // Decorative circles for depth
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 130, height: 130)
                .offset(x: -30, y: -50)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 80, height: 80)
                .offset(x: 280, y: 60)

            HStack(spacing: 14) {
                // Left — Branding
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pomodoro")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Focus")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(width: 82, alignment: .leading)
                .padding(.vertical, 4)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1)
                    .padding(.vertical, 6)

                // Right — Session rows
                VStack(spacing: 6) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                        SessionRow(
                            emoji: session.emoji,
                            label: session.label,
                            minutes: session.minutes,
                            accent: session.color
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .widgetBackground(WT.heroGradient)
    }
}

private struct SessionRow: View {
    let emoji: String
    let label: String
    let minutes: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 15))
                .frame(width: 22)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text("\(minutes)m")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accent.opacity(0.20), in: Capsule())
                .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Background helper

private extension View {
    @ViewBuilder
    func widgetBackground(_ gradient: LinearGradient) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                gradient.ignoresSafeArea()
            }
        } else {
            background(gradient)
        }
    }
}
