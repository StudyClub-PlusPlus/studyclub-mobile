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

Presentation owns UIKit screens, ViewModels, view state, and display formatting. ViewModels depend on Domain protocols. Each starts one async repository call from init through a private method, stores its display values, and exposes status notifications through a read-only Combine publisher backed by a private `CurrentValueSubject`. ViewControllers subscribe with `.sink` in `viewDidLoad`, own the resulting `AnyCancellable` values, and call `updateViews()` to read the ViewModel. Requests are not retained or cancelled by the ViewModel in the current one-request screens.

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

The Debug-only settings list uses stable section/row identifiers and diffable snapshots. A row explicitly describes either a button (optional current value) or a toggle. Cells render display values and forward interactions; persistence and setting actions are owned outside cells. Reconfiguration replaces the toggle callback, and tapping the row also toggles so the whole self-sizing row is a touch target.
