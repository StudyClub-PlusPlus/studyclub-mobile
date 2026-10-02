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

- Domain models such as `Study`
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

Presentation owns screens, ViewModels, view state, and display formatting. Main, Detail, tabs and public Setting use UIKit. Development Settings is the only scoped SwiftUI/Observation exception. ViewModels depend on Domain protocols. Main and Detail each start one async repository call from init through a private method, store their display values, and expose status notifications through a read-only Combine publisher backed by a private `CurrentValueSubject`. ViewControllers subscribe with `.sink` in `viewDidLoad`, own the resulting `AnyCancellable` values, and call `updateViews()` to read the ViewModel. Requests are not retained or cancelled by the ViewModel in the current one-request screens.

ViewControllers own UIKit lifecycle and immediate navigation. They do not decode DTOs or create concrete repository implementations.

Main passes only the selected stable ID to DetailViewModel, which obtains its own repository through the factory and starts one asynchronous detail request from init. Detail identity is checked by ID only; slug is not retained in the mobile DTO or Domain model, and Mock list/detail fixtures share numeric IDs. Detail code fields use typed Domain enums shared by the DTO; unknown values fail decoding and are classified as invalid detail data. Display text is defined in Presentation extensions on those enums. Detail uses a dedicated `StudyDetailDTO -> StudyDetail` mapping because the backend list and detail contracts differ. Its category, title, description, metadata, recruitment status, schedule, and curriculum are directly readable properties with private setters; a private subject publishes loading/content/empty/failure after display values are updated together. The `study.detail-api` flag is read when DetailViewModel is created: OFF keeps the existing Mock repository, and ON uses the configured Repository mode. A missing study is empty, while nullable detail fields remain valid content. The live client calls the public web API `GET /api/studies/{studyId}` using Production in both Debug and Release.

## Composition

`RepositoryFactory` creates repositories; the real Repository creates its API client internally. App-facing ViewModel convenience initializers call the factory, while separate repository-accepting initializers allow deterministic unit tests. Repository operations still use protocols and return Domain models; DTOs and concrete repository construction stay inside Data. Presentation may access the factory for repositories and the concrete DevelopmentSettingsStore for development configuration. No store protocol or factory wrapper is maintained while the store has one implementation and no injected consumer.

Release factory construction always returns `Repository()`. Debug reads DevelopmentSettingsStore.repositoryMode and returns either `MockRepository()` or `Repository()`; the saved mode persists across launches and defaults to Mock. MockRepository returns a static catalog of Domain Study values without DTOs, a Client double, delay, validation, cancellation checks or transport scenarios, and is compiled out of Release. Detail selects the matching known ID and falls back to the first catalog sample for an unknown ID. The real repository owns a fresh concrete `StudyAPIClient`; the Client calls `AF.request(StudyRouter.studies)`, which uses Alamofire's default Session. StudyRouter owns BaseURL, method, path and request headers. Response decoding uses Alamofire's `serializingDecodable(...).value` to match the Repository's `async throws` operations. Client/Session injection initializers are not maintained while there is only this request path. The client forwards request/DTO results and original errors; Repository maps errors at the Domain boundary. There is no API Client protocol or per-operation closure injection. Client Mock/scenario support is removed. Changing the Debug repository mode rebuilds the tab navigation stacks through MainTabBarController, so new ViewModels receive the selected implementation without replacing the window root. Revisit construction when production integration needs environment or custom Session configuration.

DevelopmentSettingsStore uses a private standard UserDefaults value with no injection initializer. Internal development settings have no automated unit suite. ViewModel tests inject Mock repositories returning Domain models. DTO-to-Study conversion stays in the existing Mapper. Repository.swift owns internal instance methods in a same-file extension for unique list IDs, requested detail identity and error classification. Error classification preserves cancellation (including Alamofire cancellation), preserves Domain errors and translates other failures. These pure rules are tested directly on a concrete Repository instance. Constructing Repository and its Client starts no request; no global helper functions or separate rule files are required. Repository connects the concrete client, mapping and validation without an isolated unit suite or API input doubles. Developers verify that connection during API integration. There are no UI-test launch arguments, environment overrides or app-only flag fixtures.

App launches use the persisted Repository mode in Debug and the explicit app default in Release. Development stores use standard UserDefaults. Unit tests inject isolated stores, repositories or typed Mock scenarios directly; there are no UI-test launch arguments, environment overrides or app-only flag fixtures.

Selecting Real constructs the live transport. The client targets `https://api.studyclub-plusplus.com/api/` in both Debug and Release. Detail is connected to the real backend contract; list API integration remains owned by its separate issue.

## Deferred abstractions

- Add a UseCase when business orchestration is reused by multiple callers or contains policy that does not belong in a repository or ViewModel.
- Add a Coordinator or Router when navigation becomes a multi-step flow with reusable branching or ownership problems.
- Add a DI container only when explicit manual composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make one feature expensive to locate or own.

## Development settings rows

The Debug-only DevelopmentSettingsView uses SwiftUI List/Section with stable section/row identifiers and typed Button/Toggle rows. The view creates and retains its @Observable DevelopmentSettingsViewModel in @State. The model creates DevelopmentSettingsStore directly and uses the static FeatureFlag.definitions catalog, with no injection initializers for this internal screen. Its initializer builds section display values; actions update persistence before rebuilding those values, and Observation invalidates the view. No Combine publisher, @Published or @AppStorage is used on this screen. The store and model own persistence/reset; the SwiftUI view only forwards actions and owns presentation state.

MainTabBarController presents a UIHostingController containing the development screen's NavigationStack. Close uses SwiftUI dismiss. Flag changes update settings in place and do not recreate the window root. The app TabBar and Main/Detail/public Setting are not migrated to SwiftUI. UIKit ViewModels retain their existing private-subject/read-only-publisher convention.

Observation follows [Apple's model data guidance](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app); this exception does not introduce an app-wide SwiftUI migration.

## Feature flag definitions and overrides

Domain defines FeatureFlag, FeatureFlagDefinition and FeatureFlagStage. Definitions have a stable storage ID, display name and stage. Ready defaults ON; InProgress defaults ON. Data's UserDefaultsFeatureFlagStore implements the Domain store contract, and RepositoryFactory constructs it. Reads resolve a per-ID developer override before the stage default in Debug. Release always returns the stage default and compiles out mutation/reset methods.

Overrides are read fresh, so changes apply to the next lookup without restarting the app. Moving a definition between stages or renaming it does not change its ID. Reset removes the entire flag override key (including retired IDs) without touching repository mode or other preferences. It does not copy current defaults into storage.


## Current public detail API integration

The backend Controller and StudyDetailResponse source, plus deployed Production responses, are the contract reference; the old get-single-study-contract.md describes a different historical response shape. Detail decodes a flat response, uses the current 11-category enum and five lifecycle statuses, and accepts null recruitStatus (omitting that display segment). Numeric ID is the only identity check; server slug and private links are not used.

The detail flag is Ready (default ON). Explicit Debug overrides remain supported. Repository mode still controls Mock/Real and keeps its existing Mock default. Real detail calls the public Production endpoint; there is no automatic fallback to Mock or Production on a Stage failure. Stage can be supplied explicitly via the client's baseURL initializer. The list API is not connected in this change, so normal Real-mode list navigation remains a separate task.

Opt-in read-only live tests use STUDYCLUB_LIVE_API_BASE_URL. They verify public details 18 and 87, missing ID 999999, ViewModel content state, and a rendered detail view attachment. These IDs are verification data only, not production navigation defaults.
