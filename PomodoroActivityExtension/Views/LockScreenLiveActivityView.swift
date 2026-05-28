import ActivityKit
import SwiftUI
import WidgetKit

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    private var progress: Double {
        context.state.progress(targetDuration: context.attributes.targetDuration)
    }

    private var accentColor: Color {
        Color(hex: context.state.sessionType.accentColorHex)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(context.state.sessionType.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(context.state.sessionType.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)

                    if !context.state.isRunning {
                        Text("· \(L10n.LiveActivity.paused)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if let task = context.attributes.taskTitle {
                    Text(task)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(accentColor)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.linear(duration: 1), value: progress)
                    }
                }
                .frame(height: 4)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                CountdownText(state: context.state)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .frame(minWidth: 70, alignment: .trailing)

                HStack(spacing: 8) {
                    if #available(iOS 17.0, *) {
                        Button(intent: ToggleTimerIntent()) {
                            Image(systemName: context.state.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(accentColor, in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Link(destination: URL(string: "pomodoro://toggle")!) {
                            Image(systemName: context.state.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(accentColor, in: Circle())
                        }
                    }

                    Text("\(context.state.completedToday) ✓")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct CountdownText: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        if state.isRunning, let endDate = state.endDate, endDate > Date() {
            Text(timerInterval: Date()...endDate, countsDown: true, showsHours: false)
        } else {
            Text(state.timeString)
                .foregroundStyle(.secondary)
        }
    }
}

