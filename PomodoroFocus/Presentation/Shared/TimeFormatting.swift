import Foundation

extension TimeInterval {
    var clockText: String {
        let totalSeconds = max(Int(rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var minutesText: String {
        L10n.Common.minutesShort(Int(self / 60))
    }

    var focusTimeText: String {
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return L10n.Common.hoursMinutesShort(hours: hours, minutes: minutes)
        }

        return L10n.Common.minutesShort(minutes)
    }
}
