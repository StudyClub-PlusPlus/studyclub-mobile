# Tabs and Development Settings

## Navigation

The app has Main (“스터디”) and Setting (“설정”) tabs, each with its own navigation stack. Switching tabs preserves navigation. Setting currently has a title and an empty list only.

## Debug entry

Only Debug builds offer Development Settings, by holding the Main tab button for 0.7 seconds. It opens a UIHostingController containing a SwiftUI NavigationStack and Close button. Only this development screen uses SwiftUI and an @Observable ViewModel; the public app remains UIKit. Ordinary taps and holding Setting do not open it. A native tab gesture may select Main while the long press is recognized. Entry and screen code are excluded from Release.

## Repository construction

Each app-facing ViewModel obtains an Alamofire-backed repository through its convenience initializer and RepositoryFactory in Debug and Release. There is no Mock/Real picker, Repository mode persistence or root recreation for transport changes. Removing Mock support does not complete [API integration](../engineering/API_INTEGRATION.md).

## Feature flags

Ready defaults ON. InProgress defaults OFF. Developer overrides persist across app launches and are keyed by a stable feature ID, not display name or stage. Overrides affect Debug only; Release uses the definition's stage default. Moving to Ready is an explicit release decision because its default becomes ON. Actual feature definitions have not yet been supplied; the app catalog is empty.

The miscellaneous list precedes Ready and InProgress. It supports button and toggle row types. “Reset Flag to Default” removes all feature flag overrides, immediately re-renders both flag sections, and preserves unrelated preferences. Each flag row has its name on the left and a switch on the right; tapping the row also toggles it. The two section headers remain visible when the catalog is empty.
