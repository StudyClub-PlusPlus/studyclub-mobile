import UIKit

enum AppTheme {
    enum Palette {
        static let canvas = UIColor.systemGroupedBackground
        static let surface = UIColor.secondarySystemGroupedBackground
        static let elevatedSurface = UIColor.tertiarySystemGroupedBackground
        static let primaryText = UIColor.label
        static let secondaryText = UIColor.secondaryLabel
        static let accent = UIColor.systemIndigo
        static let error = UIColor.systemRed
        static let border = UIColor.separator
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
