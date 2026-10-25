import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour that adapts to Light / Dark Mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum Theme {
    /// The four "Trail Signal" brand colours.
    enum Palette {
        static let forestGreen = Color(hex: 0x2D5A3D)
        static let safetyOrange = Color(hex: 0xFF7A1A)
        static let trailTeal = Color(hex: 0x1F9E9A)
        static let sandWhite = Color(hex: 0xF6F1E7)
    }

    // Semantic colours (use these in views, not the raw palette)
    static let background = Color(light: Palette.sandWhite, dark: Color(hex: 0x111A15))
    static let surface = Color(light: .white, dark: Color(hex: 0x1C2922))
    static let primary = Color(light: Palette.forestGreen, dark: Color(hex: 0x58A878))
    static let accent = Palette.safetyOrange
    static let info = Palette.trailTeal
    static let textPrimary = Color(light: Color(hex: 0x1B2A21), dark: Palette.sandWhite)
    static let textSecondary = Color(light: Color(hex: 0x5C6B62), dark: Color(hex: 0xA9B5AD))
    static let stroke = Color(light: Color(hex: 0xDCD5C4), dark: Color(hex: 0x2E3E35))

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
    }
}

enum Typography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body)
    static let caption = Font.system(.footnote)
    static let button = Font.system(.headline, design: .rounded)
}
