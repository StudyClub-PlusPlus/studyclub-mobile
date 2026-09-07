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

`SceneDelegate` creates the initial ViewModel and ViewController. Each ViewModel obtains its repository through `RepositoryFactory` in its app-facing initializer. Screens may assemble their immediate next screen when the flow is as small as Main → Detail.

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

Presentation owns UIKit screens, ViewModels, view state, and display formatting. ViewModels depend on Domain protocols. They use async repository calls and expose read-only Combine publishers backed by a private `CurrentValueSubject`. ViewControllers subscribe with `.sink` in `viewDidLoad` and own the resulting `AnyCancellable` values.

ViewControllers own UIKit lifecycle and immediate navigation. They do not decode DTOs or create concrete repository implementations.

Main passes only the selected stable ID to DetailViewModel, which obtains its own repository through the factory. DetailViewModel performs its own asynchronous detail request. Its category, title, summary, member/status text, and topics are directly readable properties with private setters; a private subject publishes loading/content/failure after display values are updated together. Production detail transport remains unconfigured until a real endpoint and schema are supplied.

## Composition

`RepositoryFactory` owns repository/client construction. App-facing ViewModel convenience initializers call it, while separate repository-accepting initializers allow deterministic unit tests. This deliberately permits a Presentation-to-Data dependency only for factory access. The default factory creates a fresh mock repository/client per ViewModel using launch arguments; live construction remains an explicit factory method.

## Deferred abstractions

- Add a UseCase when business orchestration is reused by multiple callers or contains policy that does not belong in a repository or ViewModel.
- Add a Coordinator or Router when navigation becomes a multi-step flow with reusable branching or ownership problems.
- Add a DI container only when explicit manual composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make one feature expensive to locate or own.
