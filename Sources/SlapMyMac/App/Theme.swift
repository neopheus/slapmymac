import SwiftUI

/// SlapMyMac design tokens — adaptive dark/light theme.
enum Theme {
    // Brand colors (same in both modes)
    static let accent = Color(red: 1.0, green: 0.45, blue: 0.1)       // Energetic orange #FF7319
    static let accentSoft = Color(red: 1.0, green: 0.45, blue: 0.1).opacity(0.15)
    static let purple = Color(red: 0.55, green: 0.36, blue: 0.96)     // #8C5CF5
    static let purpleSoft = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.15)
    static let green = Color(red: 0.2, green: 0.83, blue: 0.6)        // #33D499
    static let red = Color(red: 0.96, green: 0.3, blue: 0.35)         // #F54D59

    // Adaptive surface colors
    static var bg: Color {
        isLight ? Color(red: 0.96, green: 0.96, blue: 0.97) : Color(red: 0.08, green: 0.08, blue: 0.1)
    }
    static var surface: Color {
        isLight ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.15)
    }
    static var surfaceHover: Color {
        isLight ? Color(red: 0.94, green: 0.94, blue: 0.96) : Color(red: 0.16, green: 0.16, blue: 0.2)
    }
    static var border: Color {
        isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }
    static var borderLight: Color {
        isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.12)
    }

    // Adaptive text
    static var textPrimary: Color {
        isLight ? Color.black.opacity(0.88) : Color.white
    }
    static var textSecondary: Color {
        isLight ? Color.black.opacity(0.55) : Color.white.opacity(0.6)
    }
    static var textTertiary: Color {
        isLight ? Color.black.opacity(0.3) : Color.white.opacity(0.35)
    }

    // Dimensions
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 520

    // Animation
    static let springResponse: Double = 0.4
    static let springDamping: Double = 0.7

    // Helper to detect light mode
    private static var isLight: Bool {
        NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua
    }
}

/// Reusable card style for the popover.
struct CardStyle: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? Theme.surfaceHover : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(isHovered ? Theme.borderLight : Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(isHovered: Bool = false) -> some View {
        modifier(CardStyle(isHovered: isHovered))
    }
}
