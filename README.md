# Pomodoro Focus

SwiftUI Pomodoro app built with MVVM + Use Cases and repository-backed persistence.

## Project Structure

```text
PomodoroFocus/
  Core/
    DI/                  App composition and dependency wiring
    Services/            Pomodoro timer orchestration and local notifications
  Domain/
    Entities/            PomodoroSession, AppState, settings, timer status
    Repositories/        Storage contracts
    UseCases/            Read-focused app and settings use cases
  Data/
    Repositories/        UserDefaults repository implementations
    Storage/             JSON coding and first-launch storage
  Presentation/
    Splash/              Animated splash and first-launch preparation
    Home/                Settings summary, today progress, navigation
    Timer/               Countdown UI, circular progress, controls
    Shared/              Reusable styles and formatting
```

## Architecture Decisions

- SwiftUI + Combine keeps the presentation layer reactive without external dependencies.
- View models own UI state and subscribe to `PomodoroServicing`; views stay declarative.
- `TimerManager` owns timestamp-based start, pause, resume, reset, and expired-session resolution logic.
- `SettingsManager` owns persisted Pomodoro settings and publishes changes to interested screens.
- `StatsManager` owns daily aggregate stats and records completed focus sessions.
- Domain models and repository protocols are independent of UserDefaults, which leaves room for statistics, tasks, or cloud sync.
- `AppDIContainer` is the composition root, so future services can be swapped without changing screens.

## Timer Reliability

The timer does not depend on a repeating timer for correctness. A running session stores an absolute `startTime` and `duration`; remaining time is always derived from `session.endTime.timeIntervalSinceNow`.

`TimerManager` calculates elapsed time as `now.timeIntervalSince(startTime)`. This is why backgrounding, foregrounding, and reopening after process death can be resolved from persisted timestamps instead of from missed timer ticks.

`AppState` is persisted through `UserDefaultsAppStateRepository` and stores the current session, `startTime`, `duration`, paused remaining time, completed sessions today, last wall-clock update, and last known system uptime.

On launch and foreground entry, `PomodoroService.refreshTimerState()` reloads persisted state, recalculates elapsed time, completes an expired session, and republishes the restored state to SwiftUI. On background entry, the service stamps the latest state so a killed app can restore from the most recent persisted timestamp.

If the user changes system time while the same boot session is still measurable, `TimerManager` compares wall-clock delta against `ProcessInfo.processInfo.systemUptime` delta and uses uptime-corrected elapsed time when the drift is significant. After device reboot or process death without a stable monotonic reference, the app falls back to persisted wall-clock dates, which is the best available local-only behavior without a server clock.

The circular progress ring is backed by `CAShapeLayer.strokeEnd`. Starting or resuming creates one linear `CABasicAnimation` from the current real-time progress to `1.0` with `duration = remainingTime`; Core Animation handles interpolation on the render server instead of asking SwiftUI to redraw the ring every second.

When pausing, the ring reads the presentation layer's current `strokeEnd`, removes the animation, and commits that value as the model layer state. Resume continues from that captured progress using the absolute session end date.

`TimelineView` refreshes the text countdown once per second, but progress animation is not driven by text updates. When the app returns to the foreground, or is reopened after being killed, `PomodoroService.refreshTimerState()` reloads persisted state and completes an expired session if needed.

Pause stores `pausedRemaining`; resume creates a new session segment with a fresh `startTime`, preserving accuracy without accumulating drift.

Naive timer implementations usually mutate progress every second with `Timer`. That produces visible stepping, can coalesce or delay under main-thread load, and loses time while the app is suspended. This module uses timers only for coarse completion scheduling and countdown text; progress and correctness remain time based.

## Notifications

`NotificationManager` registers a Pomodoro notification category with `Start Break` and `Skip` actions. Session-end notifications include the session id, session type, and end timestamp in `userInfo`.

Notification permission denial is non-fatal: scheduling is skipped when authorization is unavailable, while the in-app timer and persisted restoration continue to work.

When an action is tapped, `PomodoroService` refreshes persisted state first. This handles the case where the timer expired while the app was killed, then applies the action: `Start Break` starts the correct break after a completed focus session, and `Skip` resets the timer.

## Settings And Stats

Settings are stored as `PomodoroSettings` through `UserDefaultsPomodoroSettingsRepository`. `SettingsViewModel` edits minute-based values, then `SettingsManager` clamps and persists them before publishing the updated settings to Home and Timer flows.

Stats are stored as `DailyStats` through `UserDefaultsDailyStatsRepository`, keyed by local calendar day. When a focus session transitions from running to completed, `PomodoroService` calls `StatsManager.recordCompletedFocusSession(duration:completedAt:)`. The manager increments `completedSessions` and adds the completed focus duration to `totalFocusTime`.

Home subscribes to both settings and today stats. That keeps the screen reactive: changing settings updates the summary, and completing a focus session updates today's completed sessions and total focus time.

## Tasks And Gamification

Tasks are stored as `PomodoroTask` records through `UserDefaultsPomodoroTaskRepository`. Home supports basic create, edit, delete, and select flows. Timer also exposes the active task picker before a session starts.

When a focus session starts, `PomodoroService` copies the current `selectedTaskID` into `PomodoroSession.taskID`. That makes task attachment immutable for the running session, even if the user selects a different task for the next session. On focus completion, the service credits the completed duration to both daily stats and the attached task.

Gamification is derived from persisted daily stats. `GamificationManager` calculates the current streak from consecutive local days with completed sessions, unlocks `10 Sessions` at ten total completed sessions, and unlocks `5 Hours Focus` when aggregate focus time reaches five hours.

## Analytics

Analytics sessions are stored separately as `FocusSession` records through `AnalyticsRepositoryImpl` under `pomodoro_sessions_v2`. Completed sessions and early resets are recorded with `sessionType`, `wasCompleted`, task metadata, actual minutes, and target minutes.

`AnalyticsView` is available from the `Thống kê` tab and always renders in light mode. It includes summary cards, a 24x7 heatmap, a 7-day focus bar chart, a 30-day session line chart, CSV export through `UIActivityViewController`, and Apple Health connection status.

Apple Health sync writes completed focus sessions as Mindful Sessions when permission is available. The app includes the HealthKit entitlement and generated Info.plist privacy strings; full HealthKit validation still needs a real device because simulator support is limited.

## Implemented Features

- Splash screen with fade/scale animation and first-launch hook.
- Home screen with current settings, completed sessions today, task progress, streak, and achievements.
- Timer screen with active task selection, start, pause, resume, reset, session switching, circular animated progress, haptics, dark-mode friendly system colors, and local end notification scheduling.
- Focus, short break, and long break cycle handling after the configured number of focus sessions.

## Build

```sh
xcodebuild -project PomodoroFocus.xcodeproj \
  -scheme PomodoroFocus \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData \
  build
```
