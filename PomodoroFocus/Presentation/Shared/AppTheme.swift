import SwiftUI

/// Centralised colour palette for the blue-and-white theme.
enum AppTheme {
    // MARK: – Core palette
    /// Deep navy – headlines, hero backgrounds.
    static let navy = Color(red: 0.06, green: 0.15, blue: 0.42)
    /// Vivid blue – primary actions, focus session.
    static let blue = Color(red: 0.16, green: 0.44, blue: 0.96)
    /// Sky blue – short break, secondary accents.
    static let sky  = Color(red: 0.35, green: 0.67, blue: 1.00)
    /// Teal – long break, tertiary accents.
    static let teal = Color(red: 0.10, green: 0.72, blue: 0.88)
    /// Ice white – page backgrounds.
    static let ice  = Color(red: 0.93, green: 0.96, blue: 1.00)

    // MARK: – Gradients
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [navy, blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
