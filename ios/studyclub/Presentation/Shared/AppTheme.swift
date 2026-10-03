import UIKit

enum AppTheme {
    // Resolve once per process; toggling/resetting flags or rebuilding the root
    // must not mix palettes and layouts. Changes apply after a cold relaunch.
    static let isStudyDesignSystemEnabled = RepositoryFactory.makeFeatureFlagStore()
        .isEnabled(FeatureFlag.studyDesignSystem.definition)

    enum Palette {
        static let canvas = AppTheme.isStudyDesignSystemEnabled ? color(0xFAF9F5) : UIColor.systemGroupedBackground
        static let surface = AppTheme.isStudyDesignSystemEnabled ? color(0xFFFFFF) : UIColor.secondarySystemGroupedBackground
        static let elevatedSurface = AppTheme.isStudyDesignSystemEnabled ? color(0xEFF6D8) : UIColor.tertiarySystemGroupedBackground
        static let primaryText = AppTheme.isStudyDesignSystemEnabled ? color(0x252522) : UIColor.label
        static let secondaryText = AppTheme.isStudyDesignSystemEnabled ? color(0x6B6A64) : UIColor.secondaryLabel
        static let accent = AppTheme.isStudyDesignSystemEnabled ? color(0x596F22) : UIColor.systemIndigo
        static let error = UIColor.systemRed
        static let border = AppTheme.isStudyDesignSystemEnabled ? color(0xE5E3DC) : UIColor.separator

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
