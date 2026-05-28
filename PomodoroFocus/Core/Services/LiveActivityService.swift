import ActivityKit
import Foundation
import UIKit

protocol LiveActivityServiceProtocol {
    var isSupported: Bool { get }
    var isActive: Bool { get }

    func start(
        sessionID: UUID,
        taskTitle: String?,
        targetDuration: Int,
        remainingSeconds: Int,
        sessionType: PomodoroSessionType,
        endDate: Date,
        completedToday: Int
    ) async throws

    func update(
        sessionID: UUID?,
        remainingSeconds: Int,
        isRunning: Bool,
        endDate: Date?,
        completedToday: Int
    ) async

    func transition(
        to sessionType: PomodoroSessionType,
        targetDuration: Int,
        remainingSeconds: Int,
        endDate: Date,
        completedToday: Int
    ) async

    func end(dismissalPolicy: LiveActivityDismissalPolicy) async
}

enum LiveActivityDismissalPolicy {
    case immediate
    case after(TimeInterval)
}

@available(iOS 16.2, *)
final class LiveActivityServiceImpl: LiveActivityServiceProtocol {
    private var currentActivity: Activity<PomodoroActivityAttributes>?

    var isSupported: Bool {
        UIDevice.current.userInterfaceIdiom == .phone &&
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isActive: Bool {
        attachedActivity()?.activityState == .active
    }

    func start(
        sessionID: UUID,
        taskTitle: String?,
        targetDuration: Int,
        remainingSeconds: Int,
        sessionType: PomodoroSessionType,
        endDate: Date,
        completedToday: Int
    ) async throws {
        guard isSupported else { return }

        if let existing = attachedActivity() {
            await existing.end(dismissalPolicy: .immediate)
        }

        let attributes = PomodoroActivityAttributes(
            sessionID: sessionID,
            taskTitle: taskTitle,
            targetDuration: targetDuration
        )
        let state = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            sessionType: map(sessionType),
            isRunning: true,
            completedToday: completedToday,
            endDate: endDate
        )
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(300))

        currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(
        sessionID: UUID?,
        remainingSeconds: Int,
        isRunning: Bool,
        endDate: Date?,
        completedToday: Int
    ) async {
        guard let activity = attachedActivity(sessionID: sessionID) else { return }

        var state = activity.content.state
        state.remainingSeconds = max(remainingSeconds, 0)
        state.isRunning = isRunning
        state.endDate = endDate
        state.completedToday = completedToday

        let content = ActivityContent(
            state: state,
            staleDate: endDate.map { $0.addingTimeInterval(300) } ?? Date().addingTimeInterval(300)
        )
        await activity.update(content)
    }

    func transition(
        to sessionType: PomodoroSessionType,
        targetDuration: Int,
        remainingSeconds: Int,
        endDate: Date,
        completedToday: Int
    ) async {
        guard let activity = attachedActivity() else { return }

        var state = activity.content.state
        state.sessionType = map(sessionType)
        state.remainingSeconds = max(remainingSeconds, 0)
        state.isRunning = true
        state.endDate = endDate
        state.completedToday = completedToday

        let mapped = map(sessionType)
        let alert = AlertConfiguration(
            title: LocalizedStringResource(stringLiteral: mapped.displayName),
            body: LocalizedStringResource(
                stringLiteral: L10n.LiveActivity.transitionBody(max(remainingSeconds / 60, 0))
            ),
            sound: .default
        )
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(300))
        await activity.update(content, alertConfiguration: alert)
    }

    func end(dismissalPolicy: LiveActivityDismissalPolicy) async {
        guard let activity = attachedActivity() else { return }

        var finalState = activity.content.state
        finalState.isRunning = false
        finalState.remainingSeconds = 0
        finalState.endDate = nil

        let finalContent = ActivityContent(state: finalState, staleDate: Date().addingTimeInterval(10))
        switch dismissalPolicy {
        case .immediate:
            await activity.end(finalContent, dismissalPolicy: .immediate)
        case .after(let interval):
            await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(interval)))
        }

        currentActivity = nil
    }

    private func attachedActivity(sessionID: UUID? = nil) -> Activity<PomodoroActivityAttributes>? {
        if let currentActivity, currentActivity.activityState == .active {
            if let sessionID {
                return currentActivity.attributes.sessionID == sessionID ? currentActivity : nil
            }
            return currentActivity
        }

        let active = Activity<PomodoroActivityAttributes>.activities.first {
            $0.activityState == .active && (sessionID == nil || $0.attributes.sessionID == sessionID)
        }
        currentActivity = active
        return active
    }

    private func map(_ type: PomodoroSessionType) -> PomodoroActivityAttributes.ContentState.SessionType {
        switch type {
        case .focus:
            return .focus
        case .shortBreak:
            return .shortBreak
        case .longBreak:
            return .longBreak
        }
    }
}

final class LiveActivityServiceStub: LiveActivityServiceProtocol {
    var isSupported: Bool { false }
    var isActive: Bool { false }

    func start(
        sessionID: UUID,
        taskTitle: String?,
        targetDuration: Int,
        remainingSeconds: Int,
        sessionType: PomodoroSessionType,
        endDate: Date,
        completedToday: Int
    ) async throws {}

    func update(
        sessionID: UUID?,
        remainingSeconds: Int,
        isRunning: Bool,
        endDate: Date?,
        completedToday: Int
    ) async {}

    func transition(
        to sessionType: PomodoroSessionType,
        targetDuration: Int,
        remainingSeconds: Int,
        endDate: Date,
        completedToday: Int
    ) async {}

    func end(dismissalPolicy: LiveActivityDismissalPolicy) async {}
}
