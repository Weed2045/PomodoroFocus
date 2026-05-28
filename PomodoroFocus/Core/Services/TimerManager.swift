import Foundation

protocol TimerManaging {
    func startSession(type: PomodoroSessionType, duration: TimeInterval, taskID: UUID?, from state: AppState, now: Date) -> AppState
    func pause(_ state: AppState, now: Date) -> AppState?
    func resume(_ state: AppState, now: Date) -> AppState?
    func reset(_ state: AppState, now: Date) -> AppState
    func resolvedState(
        from state: AppState,
        now: Date,
        complete: (_ session: PomodoroSession, _ state: AppState) -> AppState
    ) -> AppState
}

final class TimerManager: TimerManaging {
    private let significantClockChangeThreshold: TimeInterval = 60

    func startSession(type: PomodoroSessionType, duration: TimeInterval, taskID: UUID?, from state: AppState, now: Date) -> AppState {
        let session = PomodoroSession(
            type: type,
            duration: duration,
            totalDuration: duration,
            startTime: now,
            taskID: taskID,
            isCompleted: false
        )

        var nextState = state.normalizedForToday()
        nextState.currentSession = session
        nextState.status = .running
        nextState.pausedRemaining = nil
        return stamped(nextState, now: now)
    }

    func pause(_ state: AppState, now: Date) -> AppState? {
        guard let session = state.currentSession, state.status == .running else { return nil }

        let effectiveNow = clockCorrectedDate(for: state, now: now)
        var nextState = state
        nextState.status = .paused
        nextState.pausedRemaining = remainingTime(for: session, at: effectiveNow)
        return stamped(nextState, now: now)
    }

    func resume(_ state: AppState, now: Date) -> AppState? {
        guard let session = state.currentSession, state.status == .paused else { return nil }

        let remaining = max(state.pausedRemaining ?? remainingTime(for: session, at: now), 1)
        let resumedSession = PomodoroSession(
            id: session.id,
            type: session.type,
            duration: remaining,
            totalDuration: session.totalDuration,
            startTime: now,
            taskID: session.taskID,
            isCompleted: false
        )

        var nextState = state
        nextState.currentSession = resumedSession
        nextState.status = .running
        nextState.pausedRemaining = nil
        return stamped(nextState, now: now)
    }

    func reset(_ state: AppState, now: Date) -> AppState {
        var nextState = state
        nextState.currentSession = nil
        nextState.status = .idle
        nextState.pausedRemaining = nil
        return stamped(nextState, now: now)
    }

    func resolvedState(
        from state: AppState,
        now: Date,
        complete: (_ session: PomodoroSession, _ state: AppState) -> AppState
    ) -> AppState {
        let normalized = state.normalizedForToday()
        guard let session = normalized.currentSession, normalized.status == .running else {
            return stamped(normalized, now: now)
        }

        let effectiveNow = clockCorrectedDate(for: normalized, now: now)
        let resolved = elapsedTime(for: session, at: effectiveNow) >= session.duration
            ? complete(session, normalized)
            : normalized
        return stamped(resolved, now: now)
    }

    private func elapsedTime(for session: PomodoroSession, at now: Date) -> TimeInterval {
        max(now.timeIntervalSince(session.startTime), 0)
    }

    private func remainingTime(for session: PomodoroSession, at now: Date) -> TimeInterval {
        max(session.duration - elapsedTime(for: session, at: now), 0)
    }

    private func stamped(_ state: AppState, now: Date) -> AppState {
        var stampedState = state
        stampedState.lastUpdated = now
        stampedState.lastKnownUptime = ProcessInfo.processInfo.systemUptime
        return stampedState
    }

    private func clockCorrectedDate(for state: AppState, now: Date) -> Date {
        guard let lastKnownUptime = state.lastKnownUptime else { return now }

        let uptimeDelta = ProcessInfo.processInfo.systemUptime - lastKnownUptime
        guard uptimeDelta >= 0 else { return now }

        let wallClockDelta = now.timeIntervalSince(state.lastUpdated)
        let drift = abs(wallClockDelta - uptimeDelta)
        guard drift > significantClockChangeThreshold else { return now }

        return state.lastUpdated.addingTimeInterval(uptimeDelta)
    }
}
