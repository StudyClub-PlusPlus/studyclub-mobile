# Engineering Conventions

## Naming status

Current names are defaults, not a permanent style law. A rename is allowed when it improves clarity, but layer ownership must remain unchanged.

| Role | Current pattern | Example |
|---|---|---|
| Server parsing model | `*DTO` | `StudyDTO` |
| Internal application model | noun | `Study` |
| Cell display model | `*CellViewModel` | `StudyCardCellViewModel` |
| Screen load status | nested `LoadState` | `MainViewModel.LoadState` |
| Repository abstraction | noun + `Repository` | `StudyRepository` |
| Repository implementation | `Default*Repository` | `DefaultStudyRepository` |
| Composition helper | `*Factory` | `RepositoryFactory` |

Avoid mechanical names such as `RepositoryProtocol`, `RepositoryImpl`, `ServerModel`, and `ClientModel` when the role can be stated more precisely.

The model flow is `DTO -> Domain model -> ViewModel display values`:

- Data decodes a server response into a DTO and maps it to a Domain model.
- Repositories return Domain models so transport details do not escape Data.
- Presentation derives screen-ready display values from Domain models and models loading status separately inside each screen ViewModel.
- A cell ViewModel may be an immutable struct containing display formatting only. Keep it beside its cell; it does not need a repository, publisher, or reference semantics.
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
- Organize `configureView()` by view: add the view, configure its relationships or arranged subviews and custom spacing, then activate its constraints before moving to the next view. Keep a child's explicit size constraints next to its addition. Preserve stacking order and ensure a common ancestor exists before activating cross-view constraints.
- Custom accessibility support is deferred, including accessibility identifiers. UI tests locate native controls by visible text.

## Errors and copy

- Data maps transport failures into a stable application-facing error surface before Presentation formats user copy.
- User copy explains what happened and the next available action.
- Do not expose raw network or decoding messages in the UI.

## Scoped SwiftUI exception: Development Settings

Only the Debug-only Development Settings screen uses SwiftUI List, Section, Button and Toggle, presented from UIKit via UIHostingController. Its @Observable @MainActor ViewModel is owned with @State by the root SwiftUI view. Use explicit bindings that call model actions; keep UserDefaults, repository selection and flag reset in Store/ViewModel. Do not use @Published, Combine or @AppStorage for this screen. Other screens continue using UIKit, programmatic layout and private-subject/read-only-publisher observation.
