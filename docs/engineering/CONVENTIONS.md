# Engineering Conventions

## Issues, commits, and pull requests

- Start issue work from the latest agreed `main` commit on `<owner>/sc-<issue-number>` (for example, `junsu/sc-92`). Inspect local changes and fetch the remote first. If `main` is behind, fast-forward it; if it diverges, resolve the base before branching. Never discard or include unrelated local changes.
- Prefix every commit message with `[sc-<issue-number>]`, followed by its type and summary: `[sc-92] feat: 스터디 목록 engineering flag 추가`. Documentation and test commits use the same prefix. Use lowercase `sc-`; the earlier numeric-only form such as `[92]` is superseded for new commits.
- Use the same prefix in the PR title and include the actual Notion issue URL in the PR body. The Notion issue number and GitHub PR number are separate identifiers.
- Keep work branches short-lived and PRs small enough to review and integrate into trunk. One issue may have multiple PRs; link them back to that issue.
- Follow [Feature flag workflow](FEATURE_FLAGS.md) for unfinished features, including behavior and side-effect guards and ON/OFF verification.
- State the PR's completed scope, relevant flag/default, verification evidence, and shared-code impact. PR merge, issue completion, and enabling a feature by default are separate events.
- Preserve issues completed within an agreed Mock scope. Link later API integration or design changes as follow-up issues.

See the [PR template](../../.github/pull_request_template.md) and [AI handoff](AI_HANDOFF.md).

### Issue kickoff and push

1. Confirm the Notion issue and agreed scope, then create the issue branch from `main`.
2. For unfinished feature work, register an engineering flag in the existing `FeatureFlag` catalog with a stable ID and `.inProgress` (default OFF). Record the issue, current scope and activation boundary in [Feature flag workflow](FEATURE_FLAGS.md). A flag-only kickoff may register the flag before behavior exists; every later unfinished behavior and side effect must be guarded before integration.
3. Run the checks relevant to the change, inspect the diff, and stage only the intended files. Commit with the issue prefix.
4. When the requested scope includes push, push the issue branch and set its upstream on the first push. Verify the remote branch points to the local commit and report the branch, commit and remaining local changes. A successful local commit alone is not a completed push. Do not force-push or push the work directly to `main`.

For sc-92, after confirming a clean checkout and an up-to-date `main`:

```bash
git switch -c junsu/sc-92 main
# Make the scoped changes, verify them, and stage the intended files.
git commit -m "[sc-92] feat: 스터디 목록 engineering flag 추가"
git push -u origin junsu/sc-92
git rev-parse HEAD
git ls-remote --heads origin refs/heads/junsu/sc-92
git status --short --branch
```

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
