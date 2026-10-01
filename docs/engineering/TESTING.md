# Testing Policy

## Unit tests

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- repository success, empty, error propagation, cancellation behavior, and duplicate identifier rejection
- ViewModel initialization triggers one request; loading-to-content/empty/failure transitions
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

Test doubles are injected through protocols. ViewModel and repository tests supply their own dependencies; focused RepositoryFactory tests exercise factory selection explicitly. Mock scenarios remain typed inputs to MockStudyAPIClient or the explicit factory overload. App launch arguments and environment variables do not select test scenarios or preference suites.

## Manual Simulator checks

Automated UI tests and their Xcode target are not maintained at this product stage. UI changes still require a walkthrough and fresh screenshots of every changed state. Unit-test results do not prove rendered layout or interaction.

For Main/Detail changes, verify stable-ID selection, matching Detail content, back navigation, safe areas and normal-size interaction. Cover loading, empty and failure presentation when those states change. The default Mock app shows content; deterministic alternate states require an explicitly injected local QA setup, kept out of the shipped source. Label such captures as controlled QA evidence and restore the ordinary setup afterward.

## Verification order

1. Resolve packages and build from the outer repository.
2. Run relevant unit tests serially on the selected named Simulator with `-parallel-testing-enabled NO`.
3. Walk the changed user paths manually.
4. Retain fresh screenshots for UI changes and review the resulting source/layout.

Do not report a build, test, or visual pass from output produced before the last relevant source edit. Preserve Simulator data; storage cleanup is a separately authorized action.

## Development settings verification

- RepositoryModeTests cover missing/invalid preferences, store recreation, model/store consistency, no-op selection, explicit Mock scenarios, and actual Real-client selection without falling back to Mock.
- FeatureFlagStoreTests cover Ready/InProgress defaults, per-flag overrides, persistence, rename/stage promotion, malformed entries, reset idempotence and preservation of Repository/unrelated preferences. Release variants prove saved developer overrides are ignored.
- DevelopmentSettingsViewModelTests inject definitions to check section ordering and updated toggle/reset state. The app catalog contains only actual product definitions and is currently empty.
- For relevant changes, manually verify Main tab long press, rejected normal taps/Setting long press, SwiftUI hosting updates, root recreation from Detail, Mock/Real round trip and relaunch persistence. Verify flag switches and reset when actual definitions are present; unit-test fixtures do not appear in app launches.

Focused Release unit verification should run RepositoryModeTests and FeatureFlagStoreTests with `-configuration Release -enableCodeCoverage NO ENABLE_TESTABILITY=YES -parallel-testing-enabled NO`. Testability is enabled only for this test build; also build the ordinary Release app without that override. Manually verify that Release has no Development Settings entry when this boundary changes.

Custom accessibility and large-text QA are deferred at this product stage. Do not add app-defined accessibility identifiers for testing.
