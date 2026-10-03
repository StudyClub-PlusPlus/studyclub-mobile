# Tabs and Development Settings

## Navigation

The app has Main (“스터디”) and Setting (“설정”) tabs, each with its own navigation stack. Switching tabs preserves navigation. Setting currently has a title and an empty list only.

## Debug entry

Only Debug builds offer Development Settings, by holding the Main tab button for 0.7 seconds. It opens a UIHostingController containing a SwiftUI NavigationStack and Close button. Only this development screen uses SwiftUI and an @Observable ViewModel; the public app remains UIKit. Ordinary taps and holding Setting do not open it. A native tab gesture may select Main while the long press is recognized. Entry and screen code are excluded from Release.

## Repository construction

Each app-facing ViewModel obtains its repository through RepositoryFactory. Release always uses the real Repository. Debug follows the saved Mock/Real choice in Development Settings, defaulting to Mock. MockRepository returns Domain Study list and matching StudyDetail samples directly; it does not mock API Client or DTOs. Changing the mode closes Development Settings and recreates the tab navigation stacks on Main so new ViewModels use the chosen implementation. The window root is retained. Real detail integration from sc-93 is preserved; list integration remains a separate task. See [API integration status](../engineering/API_INTEGRATION.md).

## Feature flags

Ready defaults ON. InProgress defaults OFF. Developer overrides persist across app launches and are keyed by a stable feature ID, not display name or stage. Overrides affect Debug only; Release uses the definition's stage default. Moving to Ready is an explicit release decision because its default becomes ON. The catalog contains the Ready `study.detail-api` flag from sc-93. At Detail creation, Debug OFF uses MockRepository and ON follows the saved Mock/Real mode. Release always uses Real, with the current Ready default ON, ignoring saved Debug mode and flag overrides.

The miscellaneous list precedes Ready and InProgress. Its Repository button shows the current Mock/Real mode; Reset Flag to Default is a separate button. It supports button and toggle row types. “Reset Flag to Default” removes all feature flag overrides, immediately re-renders both flag sections, and preserves unrelated preferences. Each flag row has its name on the left and a switch on the right; tapping the row also toggles it. The two section headers remain visible when the catalog is empty.
