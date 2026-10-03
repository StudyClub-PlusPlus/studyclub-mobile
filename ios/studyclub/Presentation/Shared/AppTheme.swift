import UIKit

enum AppTheme {
    enum Palette {
        static let canvas = color(0xFAF9F5)
        static let surface = color(0xFFFFFF)
        static let elevatedSurface = color(0xEFF6D8)
        static let primaryText = color(0x252522)
        static let secondaryText = color(0x6B6A64)
        static let accent = color(0x596F22)
        static let error = UIColor.systemRed
        static let border = color(0xE5E3DC)

        private static func color(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let regular: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 16
    }
}
