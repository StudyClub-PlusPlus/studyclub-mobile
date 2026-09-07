# iOS Architecture

## Shape

StudyClub iOS starts with three top-level source layers:

```text
App -> Data + Presentation
Presentation -> Domain
Data -> Domain
Domain -> Foundation only
```

`App` is the composition boundary. `SceneDelegate` creates the initial concrete repository, ViewModel, and ViewController. A screen may assemble its immediate next screen from already-injected abstractions when the flow is as small as Main → Detail.

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

Main passes the selected stable ID and its injected repository abstraction to Detail at the ViewController composition site. DetailViewModel performs its own asynchronous detail request. Its category, title, summary, member/status text, and topics are directly readable properties with private setters; a private subject publishes loading/content/failure after display values are updated together. Production detail transport remains unconfigured until a real endpoint and schema are supplied.

## Composition

`RepositoryFactory` may choose mock or live dependencies based on launch configuration. It is called at an explicit composition site and its result is injected. It must not be reached from arbitrary screens or ViewModels as a global service locator.

## Deferred abstractions

- Add a UseCase when business orchestration is reused by multiple callers or contains policy that does not belong in a repository or ViewModel.
- Add a Coordinator or Router when navigation becomes a multi-step flow with reusable branching or ownership problems.
- Add a DI container only when explicit manual composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make one feature expensive to locate or own.
