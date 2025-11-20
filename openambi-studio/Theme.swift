import SwiftUI

struct AppTheme {
    static let accent = Color(red: 0.4, green: 0.2, blue: 0.8)
    static let secondary = Color(red: 0.6, green: 0.4, blue: 0.9)
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    
    static let gradient = LinearGradient(
        colors: [accent, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
