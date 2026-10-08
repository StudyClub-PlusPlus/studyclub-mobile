# iOS Architecture

## Shape

StudyClub iOS starts with three top-level source layers:

```text
App -> Presentation
Presentation -> Domain
Presentation -> Data.RepositoryFactory (repository creation)
Presentation -> Data.DevelopmentSettingsStore (development configuration)
Data -> Domain
Domain -> Foundation only
```

`SceneDelegate` installs `MainTabBarController` as the window root. It assembles independent navigation stacks for Main and Setting. Each ViewModel obtains its repository through `RepositoryFactory` in its app-facing initializer. Screens may assemble their immediate next screen when the flow is as small as Main → Detail.

## Domain

Domain owns stable application meaning:

- Domain models such as `Study` and `StudyDetail`
- repository protocols such as `RepositoryProtocol` and their Domain errors, under `Domain/Repositories`
- errors only when they describe domain meaning

Domain never imports UIKit, Combine, or Alamofire.

## Data

Data owns external representations and adapters:

- DTO decoding models
- DTO-to-Domain mappers
- concrete `StudyAPIClient` and request router
- Alamofire transport
- pure response-validation and error-classification instance methods on Repository
- concrete repositories
- composition factories

A DTO is a parsing contract, not an application model. It never crosses the repository boundary.

## Presentation

Presentation owns screens, ViewModels, view state, and display formatting. Main, Detail, tabs and public Setting use UIKit. Development Settings is the only scoped SwiftUI/Observation exception. ViewModels depend on Domain protocols. Main and Detail start an initial async repository call from init through a private method, store their display values, and expose status notifications through a read-only Combine publisher backed by a private `CurrentValueSubject`. ViewControllers subscribe with `.sink` in `viewDidLoad`, own the resulting `AnyCancellable` values, and call `updateViews()` to read the ViewModel. Detail retains its one-request policy. Main captures the list flag at creation. ON owns one Task for pagination/refresh and suppresses cancelled results. OFF requests once and disables pagination, refresh and footer UI. Real list OFF returns featureUnavailable without transport; Main shows unavailable separately from empty or failure. Mock OFF shows the current first-page Domain samples.

ViewControllers own UIKit lifecycle and immediate navigation. They do not decode DTOs or create concrete repository implementations.

Main passes only the selected stable ID to DetailViewModel, which obtains its own repository through the factory and starts one asynchronous detail request from init. Detail identity is checked by ID only; slug is not retained in the mobile DTO or Domain model, and Mock list/detail fixtures share numeric IDs. Detail code fields use typed Domain enums shared by the DTO; unknown values fail decoding and are classified as invalid detail data. Display text is defined in Presentation extensions on those enums. Detail uses a dedicated `StudyDetailDTO -> StudyDetail` mapping because the backend list and detail contracts differ. Its category, title, description, metadata, recruitment status, schedule, and curriculum are directly readable properties with private setters; a private subject publishes loading/content/empty/failure after display values are updated together. The real Repository captures the Ready `study.detail-api` flag at creation in both configurations: OFF makes no API request and returns unavailable, preserving Detail failure; ON calls the existing detail API. Mock detail always returns its trusted samples. The list flag has no effect on detail. Release ignores saved Repository mode; both configurations apply the feature flags. A missing study is empty, while nullable detail fields remain valid content. The live client calls the public web API `GET /api/studies/{studyId}` using Production in both Debug and Release.

## Composition

`RepositoryFactory` creates repositories; the real Repository creates its API client internally. App-facing ViewModel convenience initializers call the factory, while separate repository-accepting initializers allow deterministic unit tests. Repository operations still use protocols and return Domain models; DTOs and concrete repository construction stay inside Data. Presentation may access the factory for repositories and the concrete DevelopmentSettingsStore for development configuration. No store protocol or factory wrapper is maintained while the store has one implementation and no injected consumer.

Release factory construction always returns `Repository()`. List/detail factory methods delegate to the same mode-only construction; feature flags never choose the repository type. Debug reads DevelopmentSettingsStore.repositoryMode and returns either `MockRepository()` or `Repository()`; the saved mode persists across launches and defaults to Mock. MockRepository returns a static catalog of Domain Study values without DTOs, a Client double, delay, validation, cancellation checks or transport scenarios, and is compiled only in Debug. Detail returns separate trusted Domain StudyDetail samples for matching known numeric IDs; the catalog has 65 studies for manual pagination checks, and generated entries return matching-ID sample details. An unknown ID returns notFound. The real repository owns a fresh concrete `StudyAPIClient`; the Client calls `AF.request(StudyRouter.studies(offset:limit:))` or `AF.request(StudyRouter.study(id:))`, which uses Alamofire's default Session. StudyRouter owns BaseURL, method, path and request headers. Response decoding uses Alamofire's `serializingDecodable(...).value` to match the Repository's `async throws` operations. Client/Session injection initializers are not maintained for these thin request paths. The client forwards request/DTO results and original errors; Repository maps errors at the Domain boundary. There is no API Client protocol or per-operation closure injection. Client Mock/scenario support is removed. Changing the Debug repository mode rebuilds the tab navigation stacks through MainTabBarController, so new ViewModels receive the selected implementation without replacing the window root. Revisit construction when production integration needs environment or custom Session configuration.

DevelopmentSettingsStore uses a private standard UserDefaults value with no injection initializer. Internal development settings have no automated unit suite. ViewModel tests inject Mock repositories returning Domain models. DTO-to-Study and DTO-to-StudyDetail conversion stay in the existing Mappers. Repository.swift owns internal instance methods in a same-file extension for requested list offset, requested detail identity and error classification. Error classification preserves cancellation (including Alamofire cancellation), preserves Domain errors, maps HTTP 404 to notFound and decoding failures to invalidData, and translates other failures to unavailable. These pure rules are tested directly on a concrete Repository instance. Constructing Repository and its Client starts no request; no global helper functions or separate rule files are required. Repository connects the concrete client, mapping and validation without an isolated unit suite or API input doubles. Developers verify that connection during API integration. There are no UI-test launch arguments, environment overrides or app-only flag fixtures.

Selecting Real constructs the live transport. The client targets `https://api.studyclub-plusplus.com/api/` in both Debug and Release. List and Detail connect to distinct backend DTOs and Domain models.

## Deferred abstractions

- Add a UseCase when business orchestration is reused by multiple callers or contains policy that does not belong in a repository or ViewModel.
- Add a Coordinator or Router when navigation becomes a multi-step flow with reusable branching or ownership problems.
- Add a DI container only when explicit manual composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make one feature expensive to locate or own.

## Async execution boundaries

App and test Debug/Release configurations explicitly disable `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT`; other Approachable Concurrency features remain enabled. Nonisolated async Repository/Client methods run outside the caller's actor. RepositoryProtocol retains Sendable for that boundary, and the stored StudyAPIClient also conforms. StudyRouter inherits Sendable from Alamofire URLRequestConvertible and needs no repeated declaration. Domain results and errors remain Sendable for actor crossings.

## Development settings rows

The Debug-only DevelopmentSettingsView uses SwiftUI List/Section with stable section/row identifiers and typed Button/Toggle rows. The view creates and retains its @Observable DevelopmentSettingsViewModel in @State. The model creates DevelopmentSettingsStore directly and uses the static FeatureFlag.definitions catalog, with no injection initializers for this internal screen. Its initializer builds section display values; actions update persistence before rebuilding those values, and Observation invalidates the view. No Combine publisher, @Published or @AppStorage is used on this screen. The store and model own persistence/reset; the SwiftUI view only forwards actions and owns presentation state.

MainTabBarController presents a UIHostingController containing the development screen's NavigationStack. Close uses SwiftUI dismiss. Flag changes update settings in place and do not recreate the window root. The app TabBar and Main/Detail/public Setting are not migrated to SwiftUI. UIKit ViewModels retain their existing private-subject/read-only-publisher convention.

Observation follows [Apple's model data guidance](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app); this exception does not introduce an app-wide SwiftUI migration.

## Feature flag definitions and overrides

Domain defines FeatureFlag, FeatureFlagDefinition and FeatureFlagStage. The catalog contains Ready `study.detail-api` and InProgress `study.list-api` and `study.design-system` (default OFF). Definitions have a stable storage ID, display name and stage. Ready defaults ON; InProgress defaults OFF. Data's concrete DevelopmentSettingsStore owns feature overrides and the separate Debug repository-mode preference. Fixed definitions and storage keys are static constants; persisted values are read fresh rather than cached globally. Both configurations resolve saved overrides before stage defaults. Release compiles out developer entry and mutation/reset methods but reads the same overrides.

The store reads overrides fresh, so changes apply to the next lookup. The `study.design-system` visual boundary takes one immutable AppTheme decision per process; toggles/reset apply to its palette/layout/window after a cold launch, while Repository-triggered root rebuilds retain the current decision. Moving a definition between stages or renaming it does not change its ID. Reset removes the entire flag override key (including retired IDs) without touching repository mode or other preferences. It does not copy current defaults into storage.


## Current public detail API integration

The backend Controller and StudyDetailResponse source, plus deployed Production responses, are the contract reference; the old get-single-study-contract.md describes a different historical response shape. Detail decodes a flat response, uses the current 11-category enum and five lifecycle statuses, and accepts null recruitStatus (omitting that display segment). Numeric ID is the only identity check; server slug and private links are not used.

The detail flag is Ready (default ON). Persisted overrides are read in both configurations. Repository mode still controls Mock/Real and keeps its existing Mock default. Real detail calls the public Production endpoint; there is no automatic fallback to Mock or Production on a Stage failure. StudyRouter owns the fixed Production BaseURL; there is no Client/Session injection or Stage selector. sc-92 connects the recruiting list through its own list flag, paged DTO and Domain StudyPage.

Actual endpoint decoding and the installed list-to-detail path are checked during API development and recorded as dated evidence. Production-dependent XCTest cases and fixed live IDs are not maintained; unit tests use deterministic Domain inputs. Historical live-test evidence applies only to its recorded candidate.

## Paged list (sc-92)

Repository.fetchStudies(offset:) returns StudyPage with studies/totalCount/offset. Repository fixes request page size to 20 and checks only the returned offset against the request. Response limit is unused and omitted from DTO. Main stores pages by ID, keeping first position and last value for duplicates within or across pages; its snapshot IDs are unique by construction. Main keeps the raw-response cursor, merges repeated IDs across pages and manages initial/additional/refresh requests inside the existing ViewModel. Native refresh and an error-only retry footer need no pagination framework, cache or generation counter. Study no longer stores mock topics or a mock status; it stores typed category/phase, participantCount, nullable capacity and closingSoon. Mock detail curriculum is preserved independently.

## MyPage preview

MainTabBarController owns a single MyPageViewModel for both profile entry points and the My Studies boundary screen. It creates its AccountRepository through RepositoryFactory. Debug follows saved Mock/Real; Release uses Real. DTOs remain in Data, Account and its protocol in Domain. The repository owns an in-memory session; SC-52 has not supplied authenticated tokens yet. No global repository or new configuration abstraction is introduced. The MyPage feature flag is captured when tabs/model and the Real repository are constructed. The Real repository rejects disabled requests before calling its internally created AccountAPIClient, preserves cancellation, and maps failures through same-file instance rules. AccountDTO conversion lives in Data/Mappers/AccountMapper.swift. See ../product/MYPAGE_SPEC.md.
