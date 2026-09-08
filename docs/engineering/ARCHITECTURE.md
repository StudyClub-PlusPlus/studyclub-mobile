# iOS Architecture

## Shape

StudyClub iOS starts with three top-level source layers:

```text
App -> Presentation
Presentation -> Domain
Presentation -> Data.RepositoryFactory (repository creation only)
Data -> Domain
Domain -> Foundation only
```

`SceneDelegate` installs `MainTabBarController` as the window root. It assembles independent navigation stacks for Main and Setting. Each ViewModel obtains its repository through `RepositoryFactory` in its app-facing initializer. Screens may assemble their immediate next screen when the flow is as small as Main → Detail.

## Domain

Domain owns stable application meaning:

- Domain models such as `Study`
- repository protocols such as `StudyRepository`
- errors only when they describe domain meaning

Domain never imports UIKit, Combine, or Alamofire.

## Data

Data owns external representations and adapters:

- DTO decoding models
- DTO-to-Domain mappers
- API client and request router
- mock and live transports
- concrete repositories
- composition factories

A DTO is a parsing contract, not an application model. It never crosses the repository boundary.

## Presentation

Presentation owns screens, ViewModels, view state, and display formatting. Main, Detail, tabs and public Setting use UIKit. Development Settings is the only scoped SwiftUI/Observation exception. ViewModels depend on Domain protocols. Main and Detail each start one async repository call from init through a private method, store their display values, and expose status notifications through a read-only Combine publisher backed by a private `CurrentValueSubject`. ViewControllers subscribe with `.sink` in `viewDidLoad`, own the resulting `AnyCancellable` values, and call `updateViews()` to read the ViewModel. Requests are not retained or cancelled by the ViewModel in the current one-request screens.

ViewControllers own UIKit lifecycle and immediate navigation. They do not decode DTOs or create concrete repository implementations.

Main passes only the selected stable ID to DetailViewModel, which obtains its own repository through the factory and starts one asynchronous detail request from init. Its category, title, summary, member/status text, and topics are directly readable properties with private setters; a private subject publishes loading/content/failure after display values are updated together. Production detail transport remains unconfigured until a real endpoint and schema are supplied.

## Composition

`RepositoryFactory` owns repository/client construction. App-facing ViewModel convenience initializers call it, while separate repository-accepting initializers allow deterministic unit tests. Repository operations still use protocols and return Domain models; DTOs and concrete repository construction stay inside Data. This deliberately permits a Presentation-to-Data dependency only for factory access, replacing the earlier composition-root-only rule to avoid forwarding repositories through screens.

The factory creates a fresh repository/client per ViewModel; it does not share a singleton or cache. Debug reads the persisted Repository mode at each creation. Changing the mode saves it, dismisses Development Settings, and notifies SceneDelegate through callbacks to replace the window root with a fresh TabBar and navigation stacks. Existing ViewModels are not mutated or forwarded. In-flight requests may finish against discarded screens, under the existing weak-capture request policy.

Repository mode has a Domain contract and a UserDefaults implementation in Data, constructed through RepositoryFactory. Presentation depends only on the store contract plus factory creation. There is no mutable global override. Release ignores saved development settings and retains the explicit `.mock` app default until the real API contract is supplied.

`--mock-scenario` remains a Debug launch-only override for deterministic existing UI tests. Debug UI tests can set `STUDYCLUB_UI_TEST_SUITE` to a `studyclub.ui-tests.`-prefixed suite to verify persistence without changing ordinary app preferences. Release ignores both developer mode and the test suite environment. Explicit test repository injection remains separate.

The live client owns the explicitly temporary `https://api.example.invalid` default BaseURL. Selecting Real constructs the live transport; it does not make live integration ready. The existing list request fails until configured, and Detail still throws `detailAPIUnconfigured`.

## Deferred abstractions

- Add a UseCase when business orchestration is reused by multiple callers or contains policy that does not belong in a repository or ViewModel.
- Add a Coordinator or Router when navigation becomes a multi-step flow with reusable branching or ownership problems.
- Add a DI container only when explicit manual composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make one feature expensive to locate or own.

## Development settings rows

The Debug-only DevelopmentSettingsView uses SwiftUI List/Section with stable section/row identifiers and typed Button/Toggle rows. The owning view retains its @Observable DevelopmentSettingsViewModel in @State. The model stores section display values, updates persistence before rebuilding those values, and Observation invalidates the view. No Combine publisher, @Published or @AppStorage is used on this screen. Stores and the model own persistence/reset; the SwiftUI view only forwards actions and owns presentation state.

MainTabBarController presents a UIHostingController containing the development screen's NavigationStack. Close uses SwiftUI dismiss. Repository changes retain the UIKit callback chain: save in the model, dismiss the hosting controller, then SceneDelegate rebuilds the entire window root. The app TabBar and Main/Detail/public Setting are not migrated to SwiftUI. UIKit ViewModels retain their existing private-subject/read-only-publisher convention.

Observation follows [Apple's model data guidance](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app); this exception does not introduce an app-wide SwiftUI migration.

## Feature flag definitions and overrides

Domain defines FeatureFlag, FeatureFlagDefinition and FeatureFlagStage. The enum is intentionally empty until actual features are supplied. Definitions have a stable storage ID, display name and stage. Ready defaults ON; InProgress defaults OFF. Data's UserDefaultsFeatureFlagStore implements the Domain store contract, and RepositoryFactory constructs it. Reads resolve a per-ID developer override before the stage default in Debug. Release always returns the stage default and compiles out mutation/reset methods.

Overrides are read fresh, so changes apply to the next lookup without restarting the app. Moving a definition between stages or renaming it does not change its ID. Reset removes the entire flag override key (including retired IDs) without touching repository mode or other preferences. It does not copy current defaults into storage.
