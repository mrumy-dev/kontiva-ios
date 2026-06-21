import SwiftUI

/// iOS design tokens — the same calm palette as the desktop app, resolved via
/// UIColor so colours adapt to light/dark on iOS. The Swiss-red accent becomes
/// themeable later (mirroring the desktop themes); for now it is the brand default.
/// Danger semantics (negative balances, overdue, errors) always use `swissRed`.
enum KontivaTheme {

    // Fixed brand / danger constants.
    static let swissRed = Color(hex: 0xE11D2E)
    static let charcoal = Color(hex: 0x121A22)
    static let offWhite = Color(hex: 0xF6F7F8)

    // Themeable accent (brand default for now).
    static let accent = Color.adaptive(light: 0xE11D2E, dark: 0xF24A57)

    // Adaptive semantic colours.
    static let pageBackground = Color.adaptive(light: 0xF8F7F4, dark: 0x0F151B)
    static let cardSurface    = Color.adaptive(light: 0xFFFFFF, dark: 0x1A222B)
    static let textPrimary    = Color.adaptive(light: 0x121A22, dark: 0xF2F4F6)
    static let textSecondary  = Color.adaptive(light: 0x5A6672, dark: 0x9BA7B3)
    static let textTertiary   = Color.adaptive(light: 0x8A95A0, dark: 0x707C88)
    static let softBorder     = Color.adaptive(light: 0xDCE1E5, dark: 0x2A333D)
    static let positive       = Color.adaptive(light: 0x1F7A4D, dark: 0x44C088)
    static let warning        = Color.adaptive(light: 0xB26A00, dark: 0xE0A042)

    /// A whisper of depth behind the content (lighter at the top).
    static var pageGradient: LinearGradient {
        LinearGradient(colors: [Color.adaptive(light: 0xFCFBF8, dark: 0x141C24),
                                Color.adaptive(light: 0xF4F3EF, dark: 0x0D131A)],
                       startPoint: .top, endPoint: .bottom)
    }

    // Chart palette (calm, brand-aligned; red reserved for bills/overdraw).
    static let chartFixed     = Color.adaptive(light: 0x3E5C76, dark: 0x6E94B4)
    static let chartVariable  = Color.adaptive(light: 0x8AA0B0, dark: 0xAEC0CD)
    static let chartBills     = swissRed
    static let chartSavings   = Color.adaptive(light: 0x6A4C93, dark: 0x9B7FC4)
    static let chartAvailable = Color.adaptive(light: 0x1F7A4D, dark: 0x44C088)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 10
        static let tile: CGFloat = 14
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
