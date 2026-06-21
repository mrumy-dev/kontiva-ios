import SwiftUI

/// iOS design tokens — the same calm palette as the desktop app, but resolved via
/// UIColor so colours adapt to light/dark on iOS. The Swiss-red accent will become
/// themeable later (mirroring the desktop themes); for now it is the brand default.
enum KontivaTheme {
    // Fixed brand / danger colour.
    static let swissRed = Color(hex: 0xE11D2E)
    static let charcoal = Color(hex: 0x121A22)

    // Themeable accent (brand default for now).
    static let accent = Color.adaptive(light: 0xE11D2E, dark: 0xF24A57)

    // Adaptive semantic colours.
    static let pageBackground = Color.adaptive(light: 0xF8F7F4, dark: 0x0F151B)
    static let cardSurface    = Color.adaptive(light: 0xFFFFFF, dark: 0x1A222B)
    static let textPrimary    = Color.adaptive(light: 0x121A22, dark: 0xF2F4F6)
    static let textSecondary  = Color.adaptive(light: 0x5A6672, dark: 0x9BA7B3)
    static let textTertiary   = Color.adaptive(light: 0x8A95A0, dark: 0x707C88)
    static let positive       = Color.adaptive(light: 0x1F7A4D, dark: 0x44C088)

    enum Space {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    /// A colour that resolves to `light` or `dark` based on the iOS trait collection.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
