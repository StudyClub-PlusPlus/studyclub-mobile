# Feature flag workflow

## Current foundation

The app catalog in `ios/studyclub/Domain/Configuration/FeatureFlag.swift` contains Ready `study.detail-api` (default ON) and InProgress `study.design-system` (default OFF). Ready defaults ON; InProgress defaults OFF. Debug resolves saved overrides first. Debug and Release both resolve saved overrides before the stage default. Release compiles out developer entry and mutation methods.

## Design-system rollout

`study.design-system` gates the sc-116 palette, card anatomy, Detail polish and light-only window as one feature. OFF uses the previous system palette/layout and OS appearance. ON uses the selected Figma green/cream design. It does not gate API requests or change Repository mode.

AppTheme obtains the existing store from RepositoryFactory and resolves the flag once per app process. This visual boundary deliberately keeps one immutable choice: a Debug toggle or Reset changes the next cold launch, not currently visible screens or a Repository-triggered root rebuild. The switch name includes the restart requirement. This avoids combining old/new palettes and layouts while the app runs, without adding a mutable global override, DI layer or theme framework. Release uses the same saved override / stage default as Debug; without an override, this InProgress feature remains OFF. The settings UI and mutation methods remain Debug-only. Promote the same ID to Ready only when the redesigned UI is intended as the Release default.

ON/OFF native comparison and an ordinary Release build cover this slice. Automatic UI and internal settings tests/scenarios are not added for the rollout; controlled render evidence must remain distinguished from installed-app flag behavior.

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. Once the first case exists, remove the temporary empty `allCases` declaration so `CaseIterable` synthesizes the catalog.
2. Obtain `FeatureFlagStoring` through `RepositoryFactory.makeFeatureFlagStore()` in the app-facing VM initializer. Keep a separate test initializer accepting the store alongside other dependencies. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Debug reads are live. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work. Repository changes are separate: they explicitly rebuild the entire root.
5. Move the same ID to `.ready` only when the ON path is intended as the app default, including Release. Renaming the display name or moving the stage must not change the storage ID. Existing Debug overrides remain until reset.
6. Once the feature is stable and its fallback is no longer needed, remove the flag, old branch and obsolete tests in the same bounded change. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both sections and announces completion. It never changes Repository or unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Use an isolated UserDefaults suite for unit tests. UI tests explicitly enable fixture definitions in Debug via the documented test environment; these are excluded from the normal catalog and never gate product behavior. Verify both switches and full-row taps, app relaunch, Repo root recreation, reset preservation, large text, landscape, and Release isolation. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; foundation tests do not prove an unfinished feature is ready to ship.
