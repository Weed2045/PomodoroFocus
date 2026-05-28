import Foundation

extension TimeInterval {
    var clockText: String {
        let totalSeconds = max(Int(rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var minutesText: String {
        "\(Int(self / 60))m"
    }

    var focusTimeText: String {
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
