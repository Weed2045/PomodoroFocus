import SwiftUI

/// Presentation-layer extension — keeps SwiftUI and AppTheme out of the Domain layer.
extension PDFCompressionLevel {
    var accentColor: Color {
        switch self {
        case .low:    AppTheme.sky
        case .medium: AppTheme.teal
        case .high:   AppTheme.blue
        }
    }
}
