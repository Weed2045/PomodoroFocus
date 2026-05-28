import ActivityKit
import SwiftUI
import WidgetKit

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    private var progress: Double {
        context.state.progress(targetDuration: context.attributes.targetDuration)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(hex: context.state.sessionType.accentColorHex), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            Text(context.state.sessionType.emoji)
                .font(.system(size: 14))
        }
        .frame(width: 36, height: 36)
        .padding(.leading, 4)
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Button(intent: ToggleTimerIntent()) {
                    buttonImage
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: URL(string: "pomodoro://toggle")!) {
                    buttonImage
                }
            }
        }
        .padding(.trailing, 4)
    }

    private var buttonImage: some View {
        Image(systemName: context.state.isRunning ? "pause.fill" : "play.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color(hex: context.state.sessionType.accentColorHex), in: Circle())
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        VStack(spacing: 2) {
            CountdownText(state: context.state)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(context.state.isRunning ? .white : .white.opacity(0.7))

            Text(context.state.sessionType.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    private var progress: Double {
        context.state.progress(targetDuration: context.attributes.targetDuration)
    }

    var body: some View {
        VStack(spacing: 6) {
            if let task = context.attributes.taskTitle {
                Text(task)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color(hex: context.state.sessionType.accentColorHex))
                        .frame(width: geometry.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

struct CompactCountdownView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        CountdownText(state: context.state)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(Color(hex: context.state.sessionType.accentColorHex))
            .frame(minWidth: 42, alignment: .trailing)
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        Text(context.state.timeString)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(Color(hex: context.state.sessionType.accentColorHex))
    }
}

