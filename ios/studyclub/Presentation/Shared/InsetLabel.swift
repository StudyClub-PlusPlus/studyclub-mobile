import UIKit

final class InsetLabel: UILabel {
    var contentInsets = UIEdgeInsets(
        top: AppTheme.Spacing.xSmall,
        left: AppTheme.Spacing.small,
        bottom: AppTheme.Spacing.xSmall,
        right: AppTheme.Spacing.small
    ) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}
