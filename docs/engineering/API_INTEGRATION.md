# API integration status

sc-145 removes API Client Mock/scenario support and UI tests. Debug sample output comes from a Domain-model MockRepository selected through Development Settings. The merged [detail integration PR #1 (sc-93)](https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/1), included in main `c2fea74614f96210f8b9c01e32a12b389d7e84c9`, is preserved in the rebased sc-145 source. sc-92 connects the paged recruiting list below.

## Current detail implementation

StudyRouter owns the fixed Production BaseURL `https://api.studyclub-plusplus.com/api/`. Concrete StudyAPIClient calls `AF.request(StudyRouter.study(id:))`, validates the response and decodes the flat StudyDetailDTO for public `GET /api/studies/{studyId}` without authentication. The DTO maps to the separate StudyDetail Domain model. The current 11 categories, five lifecycle statuses, nullable recruitment status and optional description/curriculum/schedule fields follow sc-93's backend contract. No current-member count is invented for Detail.

Repository preserves cancellation and Domain errors, maps HTTP 404 to notFound and decoding failures to invalidData, and maps other failures to unavailable. The mapper validates positive ID/capacity, nonempty title and supplied dates; Repository checks the requested identity. DetailViewModel maps notFound, invalidData and mismatched identity to empty, and network/server errors to failure.

The Ready `study.detail-api` flag is retained. RepositoryFactory follows persisted Mock/Real in Debug (default Mock) and always Real in Release, independently of flags. Real detail captures its flag at creation: OFF returns unavailable without an API request and Detail preserves failure; ON calls the existing API. Mock detail always returns its samples, independently of both flags. Both configurations apply saved FeatureFlag overrides; only Repository mode and the developer entry differ. MockRepository returns trusted Study list and matching StudyDetail samples with numeric IDs, with no DTOs, delay or transport scenarios. There is no Client protocol, Client/Session injection or per-operation closure injection. Stage selection is not maintained; no automatic environment fallback is added.

Actual detail API compatibility is checked during integration work; production-dependent XCTest cases are no longer maintained. Preserved [sc-93 evidence](../evidence/sc-93-live/README.md) describes its earlier candidate and is historical. Current candidate verification is recorded below.

## Recruiting list implementation (sc-92)

`GET /api/studies?status=RECRUITING&offset=0&limit=20` uses the fixed Production URL. Router/Client accept offset and limit; Repository fixes limit to 20 and returns Domain StudyPage. The latest fixed source `94eb15f13c4b561e0d84ba77085c336365b25dad` uses flat items in a page object, with numeric studyId and phase (RECRUITING/ONGOING/CLOSED). Earlier OPEN/cohort notes are historical.

The list DTO reads only used fields: studyId, category, title, oneLineSummary, currentApplicants, nullable capacity, phase and closingSoon; page metadata uses Int. Slug, images and unused fields are omitted. Mapper converts the supplied numeric ID to String Study.ID and preserves server values without semantic rejection. currentApplicants counts ACTIVE/PAUSED participants, not application forms. Count above capacity is not inherently invalid. Domain values are formatted in Presentation.

InProgress `study.list-api` defaults OFF. Both Debug and Release apply stored overrides. The factory selects mode only. Real list captures its flag at creation: OFF returns featureUnavailable without an API request and Main shows unavailable; ON calls the paged API. Main captures the same list flag for ViewModel/View behavior: OFF requests only the first page of Debug Mock samples and has no pagination, refresh or footer; ON retains the existing paged/refresh behavior. MockRepository is Debug-only. No new flag catalog/Client protocol/Session injection is introduced. Detail keeps its independent flag and ID lookup.

Main owns one Task for initial page, automatic additional pages and pull-to-refresh. Content and cursor survive failed page/refresh requests. Cancelled old tasks cannot overwrite a refreshed list or stop its indicator. Same-ID cards are reconfigured and empty snapshots clear stale selection. See [list design](../product/STUDY_LIST_API_DESIGN.md) and [UI state policy](UI_STATE_POLICY.md).

During API integration, verify actual page decoding and selected-ID detail lookup and retain dated evidence; no production-dependent XCTest suite is maintained. Mapper, page/error helpers and Main state tests remain separate. Automated UI tests, JSON fixtures and thin transport doubles are not added. A source change or green test does not prove manual scrolling/rendering; fresh evidence for this candidate is reported separately.

## Current sc-92 verification (2026-10-05)

The app source in `dd1b4c56a8e8861b08a316cc0e071ec16e882d51` passed 45 serial XCTest cases with no failures on the existing iPhone 17 Pro / iOS 26.5 Simulator. Ordinary Debug and Release builds succeeded with Xcode 27.0. The subsequent documentation change does not change that app source.

Native Development Settings interaction verified persisted Mock/Real selection and list/detail switches. Debug Real list OFF showed unavailable; ON decoded seven live recruiting studies and opened the selected study's real detail. Debug Mock list OFF stopped after its first 20 samples without refresh or a footer; ON scrolled to sample 65 and opened its matching detail. Mock detail remained available with the detail flag OFF. Release ignored saved Mock mode: list ON displayed live studies, list OFF displayed unavailable, and detail OFF displayed the previous failure state.

Fresh local screenshots cover those paths. Loading/empty/failure with list OFF and ON, additional-page failure/retry and the refresh indicator were checked with temporary controlled Domain inputs in an installed Debug app. The temporary input code was removed, the app source was checked against the commit, and ordinary Debug was rebuilt. These state checks do not prove a live server failure or release readiness. The OFF no-request claim is supported by the Real Repository guards and unit tests; no independent network packet capture was performed. The live list contained one page, so multi-page interaction used Mock and deterministic tests. Deployment-specific QA and any Ready transition remain separate work.

## Historical sc-92 implementation evidence (2026-10-03)

This evidence predates flag/mode separation. In particular, Release OFF sample captures do not describe the current policy or validate this candidate.

The Swift candidate in `a2f2e0e` built in Debug and Release. Serial XCTest on the existing iPhone 17 Pro / iOS 26.5 passed all 50 tests, including opt-in Production list-to-detail integration and pagination/refresh cancellation cases. Installed Debug and Release screens showed persisted flag behavior with debugger-assisted writes through the app's UserDefaults API: Debug ON follows Mock/Real mode, Release ON uses Real with saved Mock mode, and Release OFF shows trusted samples. This does not verify Development Settings touch interaction.

Loading/content/empty/failure were captured from a temporary installed host using the same screen source and controlled Domain data; the host is excluded from the repository. Scroll, pull-to-refresh, footer taps and card-to-detail taps still need a native manual walkthrough: CUA returned `cgWindowNotFound` for native windows and its in-app browser was unavailable. Unit/integration results and installed state captures do not establish that gesture path or independent final QA.
