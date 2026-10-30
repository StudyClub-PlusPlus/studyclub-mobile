# iOS Architecture

Read this document for source ownership, dependencies, and repository composition. Use [the engineering index](INDEX.md) to load only the other rules needed for the task.

## Layers and dependencies

```text
App -> Presentation
Presentation -> Domain
Presentation -> Data.RepositoryFactory (repository creation)
Presentation -> Data.DevelopmentSettingsStore (development configuration)
Data -> Domain
Domain -> Foundation only
```

- **Domain** owns application models, repository protocols, feature-flag definitions, and errors that describe application meaning. It does not import UIKit, Combine, SwiftUI, or networking frameworks.
- **Data** owns DTOs, DTO-to-Domain mapping, request routes, API clients, transport, repository implementations, persistence, and composition. DTOs never cross into Presentation.
- **Presentation** owns screens, ViewModels, view state, display formatting, and immediate navigation. ViewModels depend on Domain protocols. ViewControllers never receive repositories or construct concrete Data objects.
- App and scene setup own the root view hierarchy and app-wide composition.

## Study repository boundary

`RepositoryProtocol` is the single Study data boundary for recruiting lists, details, and a member's study list. `Repository` implements live requests. Debug-only `MockRepository` returns trusted Domain samples. `RepositoryFactory` selects Mock or Real from the saved Debug setting; Release always selects Real. Feature flags control operations and UI behavior. They never select a repository type.

`RepositoryFactory.makeMemberRepositories()` builds the account and Study repository graph. It passes the same `DefaultAuthRepository` to `Repository` for authenticated member requests. `AuthRepository` remains separate because credentials, refresh, logout, and session invalidation have their own lifecycle. It does not create a second Study repository, API client, or router.

The same graph carries its selected Mock mode into the account presentation. Debug Mock permits local consent and signup with a short test notice; the current Real and Release flow links the web documents and allows consent and submission. Presentation does not infer that mode by rereading a saved preference after repository creation. This is test behavior, not legal approval or live OAuth evidence.

`StudyRouter` owns the shared Production `/api/` base URL, HTTP method, paths, common headers, and request-specific headers. `StudyAPIClient` owns Alamofire calls and decoding. `Repository` owns Domain error mapping, validation, feature-flag gates, and repository orchestration. Mock data contains Domain models, not DTOs or fake transport responses.

App-facing ViewModel initializers obtain repositories through `RepositoryFactory`. Separate initializers accept Domain protocols for deterministic tests. Do not add a UseCase, second Study repository, second Study router, Coordinator, or generic dependency container without a concrete second use case and an architecture decision update.

## Composition and feature settings

- Debug follows the persisted Mock/Real choice and defaults to Mock. Release always uses Real.
- Both configurations apply saved feature-flag overrides at the owning Repository or ViewModel/View boundary.
- A flag never changes repository selection. Real list OFF makes no request and reports unavailable. Mock keeps trusted Domain samples.
- Development Settings is the only SwiftUI screen. Read [SwiftUI rules](SWIFTUI.md) for its platform boundary.
- For request ownership, cancellation, and actor boundaries, read [Concurrency rules](CONCURRENCY.md).
- For per-screen loading, empty, failure, and selection rules, read [UI state policy](UI_STATE_POLICY.md).

## When to add an abstraction

- Add a UseCase when multiple callers reuse business orchestration or policy does not belong in a repository or ViewModel.
- Add a Coordinator or navigation router when a multi-step flow has reusable branching or ownership problems.
- Add a dependency container only when explicit composition becomes measurably error-prone.
- Revisit feature-first folders when top-level layers make a feature expensive to locate or own.
