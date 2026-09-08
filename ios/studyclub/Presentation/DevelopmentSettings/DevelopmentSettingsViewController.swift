#if DEBUG
import UIKit

@MainActor
final class DevelopmentSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        title = "Development Settings"
        view.backgroundColor = AppTheme.Palette.canvas
        view.accessibilityIdentifier = "development.screen"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "닫기", style: .done, target: self, action: #selector(close)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "development.close"
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
#endif
