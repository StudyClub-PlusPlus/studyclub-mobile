# Feature flag workflow

## Current foundation

The app catalog in `ios/studyclub/Domain/Configuration/FeatureFlag.swift` contains Ready study.detail-api (default ON) and InProgress study.list-api (default OFF). Ready defaults ON; InProgress defaults OFF. Both Debug and Release resolve persisted overrides before stage defaults. Only Debug exposes developer settings and mutation/reset methods. Repository mode alone differs: Debug follows its saved Mock/Real selection; Release uses Real when the feature is enabled.

List and detail flags are checked when their ViewModel is created, in both configurations. OFF selects the trusted Domain MockRepository fallback without a real API request. ON uses Debug saved Mock/Real mode or Release Real. MockRepository is included in Release for flag-OFF fallback only. List-OFF also keeps its sample-ID details in that catalog; enabled live list/details require both flags ON.

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. `CaseIterable` synthesizes the catalog; `FeatureFlag.definitions` maps it to the development rows.
2. Read configuration through the concrete `DevelopmentSettingsStore`, which owns a private standard UserDefaults value without an injection initializer. Internal development settings have no automated unit suite; do not add a protocol or factory wrapper solely for tests. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Flag reads are live in both configurations. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work.
5. Move the same ID to `.ready` only when the ON path is intended as the app default, including Release. Renaming the display name or moving the stage must not change the storage ID. Existing persisted overrides remain until reset.
6. Once the feature is stable and its fallback is no longer needed, remove the flag, old branch and obsolete tests in the same bounded change. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both flag sections without resetting the selected Repository mode. It never changes unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Internal Development Settings Store and ViewModel have no automated unit suite. The app uses only the real catalog; there are no launch-time flag fixtures. When a real flag is added or its UI changes, manually verify switches and full-row taps, app relaunch, reset preservation and landscape layout on Simulator. Manually verify that Release uses the same saved FeatureFlag overrides and stage defaults as Debug, while ignoring the saved Repository mode. Custom accessibility and large-text QA remain deferred. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; manual settings checks do not prove an unfinished feature is ready to ship.
