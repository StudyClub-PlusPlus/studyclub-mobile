# Tabs and Development Settings

## Navigation

The app has Main (“스터디”) and Setting (“설정”) tabs, each with its own navigation stack. Switching tabs preserves navigation. Setting currently has a title and an empty list only.

## Debug entry

Only Debug builds offer Development Settings, by holding the Main tab button for 0.7 seconds. It opens a UIHostingController containing a SwiftUI NavigationStack and Close button. Only this development screen uses SwiftUI and an @Observable ViewModel; the public app remains UIKit. Ordinary taps and holding Setting do not open it. A native tab gesture may select Main while the long press is recognized. Entry and screen code are excluded from Release.

## Repository construction

Each app-facing ViewModel obtains its repository through RepositoryFactory. Release always uses Real, independently of feature flags. MockRepository is compiled only in Debug. Debug follows the saved Mock/Real choice in Development Settings, defaulting to Mock. MockRepository returns Domain Study list and matching StudyDetail samples directly; it does not mock API Client or DTOs. Changing the mode closes Development Settings and recreates the tab navigation stacks on Main so new ViewModels use the chosen implementation. The window root is retained. Real detail integration from sc-93 is preserved; sc-92 adds the paged recruiting list. See [API integration status](../engineering/API_INTEGRATION.md).

## Feature flags

Ready defaults ON. InProgress defaults OFF. Developer overrides persist across app launches and are keyed by a stable feature ID, not display name or stage. Overrides are read in both Debug and Release before stage defaults. Only Repository mode differs: Release ignores its saved mode and always uses Real. Moving to Ready is an explicit release decision because its default becomes ON. The catalog contains Ready `study.detail-api` and InProgress `study.list-api`. Real Repository and MainViewModel capture immutable feature values at creation. Flags never change the chosen repository type. Real list OFF makes no API request and Main shows unavailable; Real detail OFF makes no API request and preserves failure. Mock detail always returns trusted samples. Main list OFF requests only the existing first page once and disables pagination, refresh and footer; ON retains the paged behavior. The list flag has no effect on detail. Changing a switch affects the next ViewModel, not an already-created screen.

The miscellaneous list precedes Ready and InProgress. Its Repository button shows the current Mock/Real mode; Reset Flag to Default is a separate button. It supports button and toggle row types. “Reset Flag to Default” removes all feature flag overrides, immediately re-renders both flag sections, and preserves unrelated preferences. Each flag row has its name on the left and a switch on the right; tapping the row also toggles it. The two section headers remain visible when the catalog is empty.
