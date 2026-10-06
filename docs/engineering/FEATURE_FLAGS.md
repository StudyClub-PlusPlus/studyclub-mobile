# Feature flag workflow

## Current foundation

The app catalog in `ios/studyclub/Domain/Configuration/FeatureFlag.swift` contains Ready study.detail-api (default ON) and InProgress study.list-api and study.design-system (default OFF). Ready defaults ON; InProgress defaults OFF. Both Debug and Release resolve persisted overrides before stage defaults. Only Debug exposes developer settings and mutation/reset methods. Repository mode alone differs: Debug follows its saved Mock/Real selection; Release always uses Real. Feature flags never select Mock/Real.

## Design-system rollout

`study.design-system` gates the sc-116 palette, card anatomy, Detail polish and light-only window as one feature. OFF uses the previous system palette/layout and OS appearance. ON uses the selected Figma green/cream design. It does not gate API requests or change Repository mode.

AppTheme creates the existing concrete DevelopmentSettingsStore and resolves the flag once per app process. This visual boundary deliberately keeps one immutable choice: a Debug toggle or Reset changes the next cold launch, not currently visible screens or a Repository-triggered root rebuild. The switch name includes the restart requirement. This avoids combining old/new palettes and layouts while the app runs, without adding a mutable global override, DI layer or theme framework. Release uses the same saved override / stage default as Debug; without an override, this InProgress feature remains OFF. The settings UI and mutation methods remain Debug-only. Promote the same ID to Ready only when the redesigned UI is intended as the Release default.

ON/OFF native comparison and an ordinary Release build cover this slice. Automatic UI and internal settings tests/scenarios are not added for the rollout; controlled render evidence must remain distinguished from installed-app flag behavior.

Feature flags select new versus previous behavior at the feature's Repository/ViewModel/View boundary, independently of Repository mode. Factory selects Debug saved Mock/Real or Release Real only. Real list OFF makes no API request and returns featureUnavailable; Main shows a distinct unavailable state. List OFF has no pagination, refresh or footer; Mock continues returning trusted Domain samples. Real detail OFF makes no API request and returns unavailable to preserve its previous failure presentation; ON calls the sc-93 API. Mock detail keeps its Domain samples. The list flag never changes detail behavior or implementation.

The `auth.google-login` definition is InProgress (default OFF). Both Debug and Release resolve saved overrides before the stage default through the existing store. This slice registers the flag only.

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. `CaseIterable` synthesizes the catalog; `FeatureFlag.definitions` maps it to the development rows.
2. Read configuration through the concrete `DevelopmentSettingsStore`, which owns a private standard UserDefaults value without an injection initializer. Internal development settings have no automated unit suite; do not add a protocol or factory wrapper solely for tests. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Store reads are live in both configurations. Real Repository and MainViewModel capture immutable feature values at creation; an existing screen keeps that snapshot. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work.
5. After QA for the intended deployment, move the same ID from `.inProgress` (default OFF) to `.ready` (default ON), including Release. This change does not change stages. Renaming the display name or moving the stage must not change the storage ID. Existing persisted overrides remain until reset.
6. After stability is confirmed around a later deployment, remove the flag and its previous else branch together, with obsolete tests, in the same bounded change. This change does not remove flags. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both flag sections without resetting the selected Repository mode. It never changes unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Internal Development Settings Store and ViewModel have no automated unit suite. The app uses only the real catalog; there are no launch-time flag fixtures. When a real flag is added or its UI changes, manually verify switches and full-row taps, app relaunch, reset preservation and landscape layout on Simulator. Manually verify that Release uses the same saved FeatureFlag overrides and stage defaults as Debug, while ignoring the saved Repository mode. Custom accessibility and large-text QA remain deferred. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; manual settings checks do not prove an unfinished feature is ready to ship.
