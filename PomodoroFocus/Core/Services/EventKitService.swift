import EventKit
import Foundation

@MainActor
final class EventKitService: ObservableObject {
    private let store = EKEventStore()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    var isAuthorized: Bool {
        if #available(iOS 17, *) {
            return authorizationStatus == .fullAccess
        }
        return authorizationStatus == .authorized
    }

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        AppLogger.calendar.info("📅 EventKitService init — status=\(self.statusDescription, privacy: .public)")
    }

    // MARK: – Access request

    func requestAccess() async {
        AppLogger.calendar.info("📅 requestAccess — current=\(self.statusDescription, privacy: .public)")
        do {
            if #available(iOS 17, *) {
                let granted = try await store.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
                AppLogger.calendar.info("📅 requestFullAccessToEvents → granted=\(granted, privacy: .public) status=\(self.statusDescription, privacy: .public)")
            } else {
                let granted = try await store.requestAccess(to: .event)
                authorizationStatus = granted ? .authorized : .denied
                AppLogger.calendar.info("📅 requestAccess(legacy) → granted=\(granted, privacy: .public) status=\(self.statusDescription, privacy: .public)")
            }
        } catch {
            // Do NOT force .denied here — the throw may be a transient internal
            // error (e.g. missing usage-description key in the current build),
            // not an explicit user denial. Re-read the real system status instead
            // so we don't incorrectly lock the user out of ever seeing the dialog.
            AppLogger.calendar.error("❌ requestAccess threw: \(error.localizedDescription, privacy: .public)")
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            AppLogger.calendar.info("📅 status re-read from system → \(self.statusDescription, privacy: .public)")
        }
    }

    /// Re-reads the system authorization status — call after returning from Settings.
    func refreshStatus() {
        let before = statusDescription
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        AppLogger.calendar.info("🔄 refreshStatus \(before, privacy: .public) → \(self.statusDescription, privacy: .public)")
    }

    // MARK: – Fetch events

    /// Returns all EKEvents for the given calendar day, sorted by start time.
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else {
            AppLogger.calendar.debug("📅 fetchEvents skipped — not authorized")
            return []
        }

        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        AppLogger.calendar.info("📅 fetchEvents for \(date.formatted(date: .abbreviated, time: .omitted), privacy: .public) → \(events.count, privacy: .public) events")
        return events
    }

    /// Human-readable label for the current authorization state.
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        default:
            if #available(iOS 17, *) {
                if authorizationStatus == .fullAccess  { return "fullAccess" }
                if authorizationStatus == .writeOnly   { return "writeOnly" }
            }
            return "unknown(\(authorizationStatus.rawValue))"
        }
    }
}
