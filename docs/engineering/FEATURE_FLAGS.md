# Feature flag workflow

## Current foundation

The app catalog lives in `ios/studyclub/Domain/Configuration/FeatureFlag.swift`. Engineering flags use this existing feature flag system. Ready defaults ON; InProgress defaults OFF. Debug resolves saved overrides first. Release ignores overrides and compiles out developer entry and mutation methods.

## Current catalog

| Case / storage ID | Development Settings name | Stage / default | Issue |
|---|---|---|---|
| `studyList` / `study-list` | 스터디 목록 | InProgress / OFF | [sc-92 스터디 목록](https://app.notion.com/p/benkang/3d283feabad380e995dbe12fc8ea2536) |

sc-92 kickoff registers the flag only. Debug Development Settings can toggle, persist and reset it. No product behavior reads it yet: existing Main → Detail behavior remains available with either value. Subsequent sc-92 implementation must define its lookup boundary and guard the new list behavior and side effects while retaining the existing OFF path. This registration does not mark the list feature complete or enable it for release. The list/search responsibilities are recorded in [the study list and search plan](../product/STUDY_LIST_SEARCH_PLAN.md).

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. Keep the synthesized `CaseIterable` catalog and document its issue and behavior boundary above.
2. Obtain `FeatureFlagStoring` through `RepositoryFactory.makeFeatureFlagStore()` in the app-facing VM initializer. Keep a separate test initializer accepting the store alongside other dependencies. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Debug reads are live. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work. Repository changes are separate: they explicitly rebuild the entire root.
5. Move the same ID to `.ready` only when the ON path is intended as the app default, including Release. Renaming the display name or moving the stage must not change the storage ID. Existing Debug overrides remain until reset.
6. Once the feature is stable and its fallback is no longer needed, remove the flag, old branch and obsolete tests in the same bounded change. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both sections and announces completion. It never changes Repository or unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Use an isolated UserDefaults suite for unit tests. UI tests explicitly enable fixture definitions in Debug via the documented test environment; these are excluded from the normal catalog and never gate product behavior. Also verify actual app flags without fixture definitions. Verify both switches and full-row taps, app relaunch, Repo root recreation, reset preservation, landscape, and Release isolation. Dedicated large-text QA remains deferred by the current product policy. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; foundation tests do not prove an unfinished feature is ready to ship.
