# Testing Policy

## Unit tests

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- pure response validation: requested list offset and requested detail identity; Main owns ID-based merging
- pure error classification: cancellation preservation, Domain error preservation and transport/unexpected failure translation
- ViewModel initialization triggers one request; loading-to-content/empty/failure transitions
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

ViewModel loading/content/empty/failure tests inject Mock repositories through the Domain repository protocol. DTO-to-Domain conversion is tested through the existing DTO mapper; response validation and error classification are internal instance methods in Repository.swift's same-file extension, tested directly on Repository() with values/errors without starting network requests. Tests need neither a Client protocol nor per-operation closure injection. Thin Repository/API Client wrappers do not have isolated unit suites. API integration developers verify their actual connection. Add Repository tests when it owns meaningful orchestration such as cache, pagination or retry policy. App Mock output comes from Debug MockRepository; there is no Mock Client or transport scenario selector.

JSON-to-DTO decoding is excluded from the current unit-test scope; parsing tests here mean DTO-to-Study/StudyDetail conversion. Do not add a separate unit suite for thin Alamofire request wrappers at this stage. API integration work must verify the actual endpoint, response and DTO decoding during development before commit, then check the app path. `Decodable` conformance or unit-test success does not prove compatibility with the server. Logging supports diagnosis after a failure; it does not replace that integration check. Revisit Client tests if custom request, auth, retry or serialization policy becomes substantial.

## Opt-in live detail checks

LiveStudyDetailTests remain read-only opt-in integration checks from sc-93. Set STUDYCLUB_LIVE_API_BASE_URL to `https://api.studyclub-plusplus.com/api/` to exercise Repository() against Production. Missing opt-in or a different URL skips with an explicit reason; no Client/Session injection or Stage selector is maintained. These checks cover known details 18/87, missing ID 999999 and a rendered Detail view attachment. They depend on external server data and do not prove normal live list-to-detail navigation. sc-92 adds its own opt-in list-page decoding and selected-ID detail check.

## Manual Simulator checks

Automated UI tests and their Xcode target are not maintained at this product stage. UI changes still require a walkthrough and fresh screenshots of every changed state. Unit-test results do not prove rendered layout or interaction.

For Main/Detail changes, verify stable-ID selection, matching Detail content, back navigation, safe areas and normal-size interaction. Cover loading, empty and failure presentation when those states change. Release and Debug Real mode use Alamofire; Debug Mock mode uses Domain sample studies; the current integration gap is documented in [API integration status](API_INTEGRATION.md). If a changed state needs a controlled local QA setup, keep it out of shipped source, label the evidence and restore the ordinary setup afterward.

## Verification order

1. Resolve packages and build from the outer repository.
2. Run relevant unit tests serially on the selected named Simulator with `-parallel-testing-enabled NO`.
3. Walk the changed user paths manually.
4. Retain fresh screenshots for UI changes and review the resulting source/layout.

Do not report a build, test, or visual pass from output produced before the last relevant source edit. Preserve Simulator data; storage cleanup is a separately authorized action.

## Development settings verification

- Internal Development Settings, including Store and ViewModel, have no automated unit suite. Verify relevant changes manually: Ready/InProgress defaults, overrides, persistence, reset and preservation of unrelated preferences. The app catalog contains Ready `study.detail-api` and InProgress `study.list-api`.
- For relevant changes, manually verify Main tab long press, rejected normal taps/Setting long press, SwiftUI hosting updates and Close. Verify Mock/Real selection rebuilds tabs and follows the saved mode after relaunch; Release must use Real for enabled features even when Debug saved Mock. Verify detail flag OFF uses Mock and ON follows the saved mode, plus reset and relaunch persistence; there are no launch-time flag fixtures.

Build the ordinary Release app. When this boundary changes, manually verify that Release has no Development Settings entry, ignores saved Repository mode, and applies the same saved FeatureFlag overrides as Debug.

Custom accessibility and large-text QA are deferred at this product stage. Do not add app-defined accessibility identifiers for testing.

## Main pagination

Use Domain-only test repositories to control page completion. Check cursor advancement from raw count, within-page and cross-page duplicate updates, duplicate-trigger suppression, failed-page same-offset retry, refresh failure preservation, successful empty clearing, and cancelled success/error not changing a newer request. Test real decoding separately via opt-in LiveStudyListTests; no JSON fixture/Client injection is needed. Main UI needs fresh manual evidence for content, refresh, empty/failure pull gestures and footer recovery.
