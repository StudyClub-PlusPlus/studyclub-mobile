# Testing Policy

## Unit tests

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- pure response validation: empty/unique lists, duplicate identifier rejection and requested detail identity
- pure error classification: cancellation preservation, Domain error preservation and transport/unexpected failure translation
- ViewModel initialization triggers one request; loading-to-content/empty/failure transitions
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

ViewModel loading/content/empty/failure tests inject Mock repositories through the Domain repository protocol. Conversion, response validation and error classification are tested directly with values/errors; these rules are extracted from Repository so tests need neither a Client protocol nor per-operation closure injection. Thin Repository/API Client wrappers do not have isolated unit suites. API integration developers verify their actual connection. Add Repository tests when it owns meaningful orchestration such as cache, pagination or retry policy. There is no app Mock client or scenario selector.

JSON-to-DTO decoding is excluded from the current unit-test scope; parsing tests here mean DTO-to-Study conversion. Do not add a separate unit suite for thin Alamofire request wrappers at this stage. API integration work must verify the actual endpoint, response and DTO decoding during development before commit, then check the app path. `Decodable` conformance or unit-test success does not prove compatibility with the server. Logging supports diagnosis after a failure; it does not replace that integration check. Revisit Client tests if custom request, auth, retry or serialization policy becomes substantial.

## Manual Simulator checks

Automated UI tests and their Xcode target are not maintained at this product stage. UI changes still require a walkthrough and fresh screenshots of every changed state. Unit-test results do not prove rendered layout or interaction.

For Main/Detail changes, verify stable-ID selection, matching Detail content, back navigation, safe areas and normal-size interaction. Cover loading, empty and failure presentation when those states change. Ordinary app launches use Alamofire; the current integration gap is documented in [API integration status](API_INTEGRATION.md). If a changed state needs a controlled local QA setup, keep it out of shipped source, label the evidence and restore the ordinary setup afterward.

## Verification order

1. Resolve packages and build from the outer repository.
2. Run relevant unit tests serially on the selected named Simulator with `-parallel-testing-enabled NO`.
3. Walk the changed user paths manually.
4. Retain fresh screenshots for UI changes and review the resulting source/layout.

Do not report a build, test, or visual pass from output produced before the last relevant source edit. Preserve Simulator data; storage cleanup is a separately authorized action.

## Development settings verification

- FeatureFlagStoreTests cover Ready/InProgress defaults, per-flag overrides, persistence, rename/stage promotion, malformed entries, reset idempotence and preservation of unrelated preferences. Release variants prove saved developer overrides are ignored.
- DevelopmentSettingsViewModelTests inject definitions to check section ordering and updated toggle/reset state. The app catalog contains only actual product definitions and is currently empty.
- For relevant changes, manually verify Main tab long press, rejected normal taps/Setting long press, SwiftUI hosting updates and Close. Verify flag switches, reset and relaunch persistence when actual definitions are present; unit-test fixtures do not appear in app launches.

Focused Release unit verification should run FeatureFlagStoreTests with `-configuration Release -enableCodeCoverage NO ENABLE_TESTABILITY=YES -parallel-testing-enabled NO`. Testability is enabled only for this test build; also build the ordinary Release app without that override. Manually verify that Release has no Development Settings entry when this boundary changes.

Custom accessibility and large-text QA are deferred at this product stage. Do not add app-defined accessibility identifiers for testing.
