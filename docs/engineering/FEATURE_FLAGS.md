# Feature flag workflow

## Current foundation

The app catalog in `ios/studyclub/Domain/Configuration/FeatureFlag.swift` contains the Ready study.detail-api flag (default ON). Ready defaults ON; InProgress defaults OFF. Debug resolves saved overrides first. Release ignores overrides and compiles out developer entry and mutation methods.

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. Once the first case exists, remove the temporary empty `allCases` declaration so `CaseIterable` synthesizes the catalog.
2. Read configuration through the concrete `DevelopmentSettingsStore`, which owns a private standard UserDefaults value without an injection initializer. Internal development settings have no automated unit suite; do not add a protocol or factory wrapper solely for tests. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Debug reads are live. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work.
5. Move the same ID to `.ready` only when the ON path is intended as the app default, including Release. Renaming the display name or moving the stage must not change the storage ID. Existing Debug overrides remain until reset.
6. Once the feature is stable and its fallback is no longer needed, remove the flag, old branch and obsolete tests in the same bounded change. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both flag sections without resetting the selected Repository mode. It never changes unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Internal Development Settings Store and ViewModel have no automated unit suite. The app uses only the real catalog; there are no launch-time flag fixtures. When a real flag is added or its UI changes, manually verify switches and full-row taps, app relaunch, reset preservation and landscape layout on Simulator. Manually verify that Release ignores saved overrides and uses stage defaults when actual definitions are present. Custom accessibility and large-text QA remain deferred. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; manual settings checks do not prove an unfinished feature is ready to ship.
