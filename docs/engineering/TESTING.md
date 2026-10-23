# Testing Policy

Read [Simulator test storage](SIMULATOR_TESTING.md) before running XCTest. The specific task may set stricter limits.

## Unit tests

SC77 adds a focused synthetic public-detail decoding check for the removed deliveryFormat boundary: valid supplied value, omitted/null value, wrong type/unknown enum, and missing/invalid identity. This scoped contract regression does not add a general DTO JSON fixture suite or production-dependent tests. Detail ViewModel also checks omission of only the unavailable metadata segment.

Feature-boundary tests directly verify Real OFF errors, distinct Main unavailable presentation and OFF suppression of repeated requests with immutable bool inputs. Existing ON pagination/refresh tests remain. These are feature behavior tests, not an internal settings suite. No Client injection or live endpoint tests are added.

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- pure response validation: requested list offset and requested detail identity; Main owns ID-based merging
- pure error classification: cancellation preservation, Domain error preservation and transport/unexpected failure translation
- ViewModel initialization triggers one request; loading-to-content/empty/failure/unavailable transitions
- Setting account transitions use an auth repository double: restore, login, signup, recheck, logout, flag OFF/ON, cancellation, unconfirmed-terms refusal, and a thrown `discardPendingSignup()` that stays retryable instead of a completed cancellation. They do not claim a real Google login.
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

ViewModel loading/content/empty/failure tests inject Mock repositories through the Domain repository protocol. DTO-to-Domain conversion is tested through the existing DTO mapper; response validation and error classification are internal instance methods in Repository.swift's same-file extension, tested directly on Repository() with values/errors without starting network requests. Tests need neither a Client protocol nor per-operation closure injection. Thin Repository/API Client wrappers do not have isolated unit suites. API integration developers verify their actual connection. Add Repository tests when it owns meaningful orchestration such as cache, pagination or retry policy. App Mock output comes from Debug MockRepository; there is no Mock Client or transport scenario selector.

JSON-to-DTO decoding is excluded from the current unit-test scope; parsing tests here mean DTO-to-Study/StudyDetail conversion. Authentication is the exception: `AuthContractTests` decodes the login `AccountView` and `GET /auth/me` `AccountSelfView` shapes, checks root auth paths and classifies HTTP and cancellation errors without a live request. Do not add a separate unit suite for thin Alamofire request wrappers at this stage. `DefaultAuthRepository` owns session orchestration, so its cancellation, late completion, credential and error distinctions are tested directly with in-memory collaborators and a suspension gate. Those tests do not sleep. Synchronous storage gates also cover stage, final commit, cancellation, OFF and awaited OFF-to-ON invalidation. Faulted byte persistence runs the actual KeychainCredentialStore policy to verify compensation, fresh-instance reconciliation and preservation of prior/newer credentials; it does not mirror that policy in a test store. The actual Keychain round trip remains separate. Malformed account decoding/recheck must never unlock a second onboarding POST. Debug Mock auth is not a live login. API integration work must verify the actual endpoint, response and DTO decoding during development before commit, then check the app path. `Decodable` conformance or unit-test success does not prove compatibility with the server. Logging supports diagnosis after a failure; it does not replace that integration check. Revisit Client tests if custom request, auth, retry or serialization policy becomes substantial.

## Actual API checks during development

Verify the actual endpoint, response decoding and list-to-detail connection when changing API integration, then retain dated evidence for that candidate. Do not maintain production-dependent XCTest cases or fixed live IDs as a regression suite. Unit tests remain deterministic and independent of server availability. Actual API and installed-app observations are separate from unit-test results.

## Manual Simulator checks

Search tests use a suspended Domain Repository and request/state expectations for blank/OFF/composition gating, debounce replacement, cancelled old responses, deletion/dismissal, filter changes during pagination, raw offsets, duplicate IDs, empty, failure/retry and stalled pages. They contain no sleep/yield polling. These checks do not prove UIKit IME callbacks, rendered menus, search dismissal, actual browsing scroll restoration or live selected-ID navigation. Walk those paths with `study.search` ON and OFF, capture initial/loading/content/empty/failure and filter states, and identify Mock versus public Real evidence. The flag remains InProgress/default OFF.

Automated UI tests and their Xcode target are not maintained at this product stage. UI changes still require a walkthrough and fresh screenshots of every changed state. Unit-test results do not prove rendered layout or interaction.

For Main/Detail changes, verify stable-ID selection, matching Detail content, back navigation, safe areas and normal-size interaction. Cover loading, empty and failure presentation when those states change. Release and Debug Real mode use Alamofire; Debug Mock mode uses Domain sample studies; the current integration gap is documented in [API integration status](API_INTEGRATION.md). If a changed state needs a controlled local QA setup, keep it out of shipped source, label the evidence and restore the ordinary setup afterward.

## Verification order

1. Resolve packages and build from the outer repository.
2. Run relevant unit tests serially on the selected named Simulator with `-parallel-testing-enabled NO`.
3. Walk the changed user paths manually.
4. Retain fresh screenshots for UI changes and review the resulting source/layout.

Do not report a build, test, or visual pass from output produced before the last relevant source edit. Preserve Simulator data; storage cleanup is a separately authorized action.

## Development settings verification

- Internal Development Settings, including Store and ViewModel, have no automated unit suite. Verify relevant changes manually: Ready/InProgress defaults, overrides, persistence, reset and preservation of unrelated preferences. The app catalog contains Ready `study.detail-api`, `study.list-api` and `study.design-system`.
- For relevant changes, manually verify Main tab long press, rejected normal taps/Setting long press, SwiftUI hosting updates and Close. Verify Mock/Real selection rebuilds tabs and follows the saved mode after relaunch; Release must always use Real even when Debug saved Mock. Verify flags never change repository type: Real list OFF makes no request and shows unavailable; Real detail OFF makes no request and shows failure; Mock detail keeps its samples in every flag combination. Verify Main OFF requests once without refresh, pagination or footer and ON retains those behaviors, plus reset and relaunch persistence; there are no launch-time flag fixtures.

Build the ordinary Release app. When this boundary changes, manually verify that Release has no Development Settings entry, ignores saved Repository mode, and applies the same saved FeatureFlag overrides as Debug. Verify design flag OFF/ON, persistence, cold-relaunch application and Reset with bounded native observation; distinguish controlled renders from installed-app behavior.

Custom accessibility and large-text QA are deferred at this product stage. Do not add app-defined accessibility identifiers for testing.

## Main pagination

Use Domain-only test repositories to control page completion. Check cursor advancement from raw count, within-page and cross-page duplicate updates, duplicate-trigger suppression, failed-page same-offset retry, refresh failure preservation, successful empty clearing, and cancelled success/error not changing a newer request. Verify actual decoding during API development; no maintained live tests, JSON fixture or Client injection is needed. Main UI needs fresh manual evidence for content, refresh, empty/failure pull gestures and footer recovery.

MockRepository keeps 65 trusted Domain studies, paged in groups of 20, with matching-ID details. Use this ordinary Debug Mock mode with list ON for manual multi-page scrolling and end-of-list checks; list OFF displays the first page once without refresh or pagination; no transport scenario or test-only app configuration is needed.

## MyPage

The obsolete independent AccountRepository/MyPageViewModel and their tests are removed. Existing Auth/SettingAccountViewModel tests cover the shared session policy; new screen wiring still needs fresh manual evidence. Check both profile roots, guest explicit login, nickname, checking/recheck/logoutFailure, login/signup safe close and the fullScreen return contract without changing either tab's existing navigation stack. Old ../evidence/sc-94-review captures remain historical. Controlled hosts stay outside shipped source, and real OAuth/deployed account data remain separate unknowns. Do not add automated UI tests.

## Shared member root integration

MemberAreaViewModelTests uses Domain-only collaborators to check guest bootstrap, confirmed member loading and logout clearing, auth OFF with no restore/list request, and an authorization recheck while logout is explicitly suspended. MemberAuthorizationTests includes two continuation probes for final rejection followed by a late concurrent refresh, including deletion failure. MyStudiesListIntegrationTests covers session changes, cancellation, refresh preservation/empty replacement and onboarding rejection. These unit checks do not establish fullScreen return behavior, live OAuth or deployed server compatibility. Native root walkthroughs must bind the exact shipping source or identify every controlled-host difference and runtime mode. Legal consent guards stay intact.

The final root regression uses a restore continuation and a one-shot state publisher to finish the same-member rejection check. It asserts one automatic list request and allows a second request only after explicit refresh. Separate root checks preserve the onboarding guest instruction and ensure sibling refresh cannot bypass failed cleanup. The pre-fix probe's second-request barrier is retained only in its archived candidate.

SC73 exercises the actual Debug MockAuthRepository through the shared member root: required consent remains explicit, signup loads the member list, logout clears it, and abandoned signup clears consent before the next attempt. Existing negative tests keep unapproved Real consent blocked and cover failures, uncertain completion and cancellation. The Mock exception leaves AuthDocuments false and does not complete live OAuth or legal approval.
