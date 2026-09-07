# Engineering Conventions

## Naming status

Current names are defaults, not a permanent style law. A rename is allowed when it improves clarity, but layer ownership must remain unchanged.

| Role | Current pattern | Example |
|---|---|---|
| Server parsing model | `*DTO` | `StudyDTO` |
| Internal application model | noun | `Study` |
| Screen-ready display value | `*ViewData` | `StudyListItemViewData` |
| Display state | `*ViewState` | `MainViewState` |
| Repository abstraction | noun + `Repository` | `StudyRepository` |
| Repository implementation | `Default*Repository` | `DefaultStudyRepository` |
| Composition helper | `*Factory` | `RepositoryFactory` |

Avoid mechanical names such as `RepositoryProtocol`, `RepositoryImpl`, `ServerModel`, and `ClientModel` when the role can be stated more precisely.

The model flow is `DTO -> Domain model -> ViewData/ViewState`:

- Data decodes a server response into a DTO and maps it to a Domain model.
- Repositories return Domain models so transport details do not escape Data.
- Presentation derives screen-ready `ViewData` and exhaustive `ViewState` from Domain models.
- ViewData is optional for a simple screen, but when it exists it must contain display meaning only and must not become a second business model.

## Repository creation

- App-facing ViewModel initializers obtain repositories through `RepositoryFactory`. ViewControllers do not receive or forward repositories.
- Keep a separate initializer accepting a repository protocol for deterministic unit tests.
- No dependency factory in a default initializer argument.
- Tests supply their own repository or client test double.
- Factories may build object graphs but do not expose mutable global state.

## Concurrency and binding

- Repository operations use `async throws`.
- UI-facing ViewModels are `@MainActor`.
- Current screens fetch once from ViewModel init via a private method. Do not add load flags, retry, Task retention, or cancellation management until the feature requires them.
- Domain values crossing concurrency boundaries conform to `Sendable` where practical.
- ViewModels keep mutable state in a private `CurrentValueSubject` when the current value must replay to a newly bound view.
- ViewControllers subscribe with `.sink` during `viewDidLoad` and retain the subscription in `Set<AnyCancellable>`.
- Expose `AnyPublisher` instead of a writable subject so views cannot mutate ViewModel state.
- Combine binds ViewModel state to UIKit. It does not replace async networking.

## UIKit

- Build views in code with Auto Layout; set `translatesAutoresizingMaskIntoConstraints = false` explicitly.
- Use semantic colors, preferred fonts, safe areas, and self-sizing layouts.
- Keep reusable visual constants in `AppTheme`.
- Screens, cells, and shared views store fixed views as `private let` properties with fixed styling in initialization closures. Data-driven rows may use a local factory.
- `configureView()` adds subviews and sets constraints and spacing together; `updateViews()` reads display values from the ViewModel after a Combine notification. Update all display values before publishing the notification. Cells and shared views also use `updateViews` for data application.
- Give user-visible controls and content stable accessibility identifiers when UI tests need them.

## Errors and copy

- Data maps transport failures into a stable application-facing error surface before Presentation formats user copy.
- User copy explains what happened and the next available action.
- Do not expose raw network or decoding messages in the UI.
