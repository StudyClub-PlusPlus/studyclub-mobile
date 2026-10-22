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

SC70 adds a Debug-only saved mock session choice to DevelopmentSettingsStore. Each new MockAuthRepository seeds guest or a trusted `테스트 회원` Domain sample from that choice; credentials and OAuth are untouched. Development Settings offers this choice only in Mock mode and reuses the existing repository-change callback to invalidate the old account workflow and rebuild tabs. Selecting the same sample again restores it after mock logout. Flag overrides and repository mode remain independent, and flag reset preserves the mock choice. Release compiles out the choice and uses real auth. SC68's shared root graph uses the same MockAuthRepository initializer, so the selected session reaches My Studies without a second session owner.

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

## Authentication session (sc-51)

`AuthRepository` is the completed-member session contract: Google sign-in, signup completion, completion recheck, restoration, logout and `discardPendingSignup()`. Domain models are `Member`, `MemberRegistration` and `SignInOutcome`. Tokens, DTOs and the Google SDK stay in Data. The protocol and its errors import Foundation only.

`RepositoryFactory.makeAuthRepository()` returns a new repository on every call. Debug follows the saved Mock/Real mode and Release always returns `DefaultAuthRepository`. The `auth.google-login` flag does not choose the type. `SettingAccountViewModel` is the feature owner and keeps one instance for the login and onboarding callbacks. Its app-facing initializer calls `makeAuthRepository()`. View controllers subscribe to its presentation and pass the existing display models into the login and onboarding screens. They do not receive the repository. Replacing the tab root awaits `invalidate()`, which calls `discardPendingSignup()` before the next settings model is created. If that call throws, the current tabs and completed credentials stay. Main shows a general retry with no nickname and runs the same invalidation again. Dismissing that alert does not install the next root or clear the failure. Settings keeps its existing recovery. When the account flag is on, settings can still show `connectionFailure`.

`DefaultAuthRepository` is an actor. Its per-instance lock-protected epoch invalidates in-flight work. `discardPendingSignup() async throws` signals invalidation before waiting for the actor, so a request made during a synchronous credential write remains visible after OFF returns to ON. It drops in-memory signup and waits for compensation of the invalidated write. Final result publication and invalidation use the same per-instance lock to order their epoch check without a gap. The feature owner must await it on cancellation, close, OFF and root replacement. Failure stays a failure with retry; it must not be hidden with `try?` or shown as completed cancellation. Previously completed credentials stay. Logout deletes those credentials and throws `logoutFailed` when deletion fails. OFF starts no Google/API/automatic restoration, but bounded cleanup of an already-started invalidated write is allowed.

Credential writes stage a separate Keychain item, then replace the active item with an attempt UUID and previous completed credentials. The Repository checks cancellation/epoch/OFF before and after synchronous writes, including cleanup. Compensation restores/deletes only the still-matching active UUID; it cannot delete a newer completed session. An invalidation marker is recorded before compensation. If active compensation fails after that marker is stored, a fresh store retries it before returning credentials. Pending cleanup alone is best effort: an orphan stage never becomes a session. Failure to persist both invalidation and compensation remains failed invalidation, not a cancellation success. One process-local store mutex serializes conditional I/O across instances; it owns no session state. The raw persistence seam exists only to fail physical operations while testing the actual store policy.

Only a server-confirmed complete account is saved: a positive ID, required usable nickname and an explicit completion key containing a valid server UTC Instant. Explicit null completion means incomplete; missing/garbage fields are errors. Submit/recheck must match the account ID captured at login. Empty access/refresh tokens are rejected before persistence or authorization. Incomplete signup tokens stay in memory. Process termination drops them. An uncertain signup submit is not repeated; `checkSignupCompletion()` reads `GET /auth/me`. The first HTTP 401 refreshes once through `POST /auth/refresh`. Confirmed invalid authentication deletes stored credentials and returns anonymous. A failed delete stays a failure. Transient failures keep the stored credentials.

Auth routes use `https://api.studyclub-plusplus.com` without the `/api` prefix: `POST /auth/social-login`, `GET /auth/me`, `POST /auth/refresh`, `POST /accounts/onboarding`. Social login sends `provider=google` and `platform=CORE` and omits `redirectUri`. `GET /auth/me` may include `discordNickname`; the member model keeps only the nickname. Google sign-in starts only when Info.plist has `GIDClientID`, `GIDServerClientID` and the reversed client-ID URL scheme. `SceneDelegate` forwards the callback URL to the SDK. There is no verified OAuth client configuration in the app, so that start is refused. The installed GoogleSignIn package is 10.0.0. Debug `MockAuthRepository` returns trusted in-memory samples and performs no Google or network call.
## Shared account surface · SC94

MainTabBarController owns one SettingAccountViewModel for its root lifetime; that model creates its AuthRepository through RepositoryFactory. Both profile entry points and the My Studies boundary read the same model. The independent AccountRepository, Account DTO/client and in-memory tokens have been removed. Debug/Release mode selection and SC51 authentication policies remain unchanged.

MyPageViewController keeps the original scrollable profile card. It subclasses the existing SettingViewController's authentication presentation/lifecycle implementation and overrides only configureView/updateViews. The two concrete visual surfaces share login, signup, cleanup alerts and logout confirmation instead of duplicating session policy. UIKit controllers receive display models and callbacks, never repositories. The concrete shared hooks are local to Presentation; no Router, Coordinator or DI container is added.

The profile opens in its own fullScreen UINavigationController. Dismissal preserves both top-level tab navigation stacks and the originating selection. Explicit profile login returns to the open profile; My Studies gate login dismisses the account flow back to its origin after completion or safe cancellation. Failed cleanup preserves the current flow. The account.mypage flag gates the new entry/tab structure; auth.google-login separately gates authentication. OFF retains the prior Main/Setting structure. The My Studies list API remains SC68's separate feature. See ../product/MYPAGE_SPEC.md.
