import SwiftUI

/// Design tokens from the LingvoBuddy design file (dark only).
enum Theme {
    enum Palette {
        static let panel = Color(hex: 0x1E1E20)
        static let raised = Color(hex: 0x2C2C2E)
        /// Dictionary sidebar and Settings sections: a step darker than the panel.
        static let sidebar = Color(hex: 0x1A1A1C)
        /// The inside of text fields.
        static let inset = Color(hex: 0x141416)
        static let border = Color(hex: 0x3A3A3C)
        static let hairline = Color.white.opacity(0.10)
        static let accent = Color(hex: 0x0A84FF)
        static let success = Color(hex: 0x30D158)
        static let wrong = Color(hex: 0xFF9F0A)
        static let wrongText = Color(hex: 0xFFB340)
        static let textPrimary = Color(hex: 0xF5F5F7)
        static let textStrong = Color.white
        static let textSecondary = Color(hex: 0xA1A1A6)
        static let textBody = Color(hex: 0xD1D1D6)
        static let keyBadge = Color.white.opacity(0.08)
        static let desktop = Color(hex: 0x33404D)
        static let shadow = Color.black.opacity(0.45)
    }

    enum Radius {
        static let card: CGFloat = 14
        static let tray: CGFloat = 12
        static let option: CGFloat = 10
        static let button: CGFloat = 8
        static let smallButton: CGFloat = 7
        static let chip: CGFloat = 6
        static let keyBadge: CGFloat = 5
    }

    enum FontSize {
        static let word: CGFloat = 34
        static let stat: CGFloat = 18
        static let option: CGFloat = 15
        static let title: CGFloat = 14
        static let body: CGFloat = 13
        static let caption: CGFloat = 12
        static let small: CGFloat = 11
        static let keyBadge: CGFloat = 11
    }

    /// CSS `box-shadow: 0 18px 50px`: SwiftUI's radius is about half the CSS blur.
    enum CardShadow {
        static let radius: CGFloat = 25
        static let offsetY: CGFloat = 18
        /// Transparent room around the card so the shadow is not clipped.
        static let insets = EdgeInsets(top: 8, leading: 28, bottom: 48, trailing: 28)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
