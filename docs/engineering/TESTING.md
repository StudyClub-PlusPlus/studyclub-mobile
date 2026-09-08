# Testing Policy

## Unit tests

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- repository success, empty, error propagation, cancellation behavior, and duplicate identifier rejection
- ViewModel initialization triggers one request; loading-to-content/empty/failure transitions
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

Test doubles are injected through protocols. Tests must not call the static factory from the system under test.

## UI tests

Mock behavior is selected with deterministic launch arguments:

- `--mock-scenario content`
- `--mock-scenario empty`
- `--mock-scenario failure`
- `--mock-scenario loading`
- `--mock-scenario detail-failure`
- `--mock-scenario detail-loading`

Required smoke flows:

1. Content launches and the second study opens the matching Detail.
2. Empty state renders without cells.
3. Main failure and empty states expose no retry/reload action.
4. Loading remains visible while a deterministic long-running request is active.
5. Detail failure has no retry button; both failure and loading allow back navigation.
6. Main and Detail screenshots are retained in XCTest result attachments.

## Verification order

1. Resolve packages and build.
2. Run unit tests.
3. Run focused UI tests on a named Simulator.
4. Walk all product states manually.
5. Capture fresh screenshots and run independent visual/code review.

Do not report a build, test, or visual pass from output produced before the last relevant source edit.

## Development settings verification

- RepositoryModeTests cover missing/invalid preferences, store recreation, model/store consistency, no-op selection, and actual Real-client selection without falling back to Mock.
- FeatureFlagStoreTests cover Ready/InProgress defaults, per-flag overrides, persistence, rename/stage promotion, malformed entries, reset idempotence and preservation of Repository/unrelated preferences. Release variants prove saved developer overrides are ignored.
- DevelopmentSettingsViewModelTests check section ordering and that toggle/reset actions expose the updated state.
- DevelopmentSettingsUITests exercise the actual Main tab long press and SwiftUI hosting/Observation updates, rejected normal taps/Setting long press, root recreation from Detail, Mock/Real round trip, app relaunch, flag switches and reset.
- Flag UI tests opt into two clearly named fixture definitions using `STUDYCLUB_UI_TEST_FLAGS=1` plus a unique `STUDYCLUB_UI_TEST_SUITE=studyclub.ui-tests.<UUID>`. Both requirements and all fixture code are Debug-only. These definitions do not enter FeatureFlag or gate product behavior; ordinary launches have no flag rows yet. Captures with `fixture` in their names are test-fixture UI evidence, not an actual feature rollout.
- Run XCTest serially with `-parallel-testing-enabled NO` on the selected named device. UI tests verify relaunch within the same isolated preference suite. Screenshots are retained in result attachments.

Focused Release verification should run RepositoryModeTests, FeatureFlagStoreTests and DevelopmentSettingsUITests/testOnlyMainTabLongPressOpensDevelopmentSettings using `-configuration Release -enableCodeCoverage NO ENABLE_TESTABILITY=YES -parallel-testing-enabled NO`. Testability is enabled only for the unit-test build; additionally build the ordinary Release app without that override. Release app launches ignore mock-scenario arguments; scenario-driven UI flows are Debug checks.
