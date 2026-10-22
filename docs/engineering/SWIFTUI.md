# SwiftUI rules

UIKit and programmatic Auto Layout remain the app default. The Debug-only Development Settings screen is the only approved SwiftUI exception. Read [Architecture](ARCHITECTURE.md) for layer ownership and [Feature flags](FEATURE_FLAGS.md) for flag behavior.

## Development Settings

- `DevelopmentSettingsView` uses SwiftUI `List`, `Section`, `Button`, and `Toggle`, hosted by UIKit with `UIHostingController`.
- The root SwiftUI view owns its `@Observable @MainActor` ViewModel with `@State`.
- The ViewModel creates `DevelopmentSettingsStore` and uses the static `FeatureFlag.definitions` catalog. Persistence and reset logic stay in the Store/ViewModel; the view only forwards actions and owns presentation state.
- Use explicit bindings that call ViewModel actions. Do not use `@Published`, Combine, or `@AppStorage` on this screen.
- Settings presents a `NavigationStack` inside its hosting controller. Close uses SwiftUI `dismiss`.
- Feature-flag changes update settings in place. They do not replace the window root. Changing Repository mode uses the existing callback to rebuild the tab stacks.
- Do not migrate the app TabBar, Main, Detail, or public Setting to SwiftUI without a separate architecture decision.

Apple reference: [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app).
