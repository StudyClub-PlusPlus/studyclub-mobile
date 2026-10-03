# Engineering Conventions

## Issues, commits, and pull requests

- Start implementation from a matching Notion issue and a work branch. If no ticket exists, draft the purpose, change, scope, completion criteria and verification from the request; ask only for missing details or a consequential decision before creating the ticket. An explicit request to create the ticket and do the already-defined work does not need repeated confirmation.
- Reuse an existing matching issue. Create new tickets in the team's existing issue database and read back the real issue number and URL before creating the branch. Never invent an issue number or use a GitHub issue/PR number in its place.
- Use `sc-<Notion issue number>` for the work branch and `[sc-<number>]` for commit/PR prefixes (for example, branch `sc-145` and `[sc-145] refactor: UI 테스트 지원 제거`). Use the repository's integration base. In Orca, create the managed worktree, then verify or rename the generated branch to this exact key before implementation. Link the Notion URL in the worktree comment and ticket body; Orca's `--issue` flag refers to GitHub issues.
- The installed `notion-ticket-branch` skill handles task intake, ticket reuse/creation and branch preparation. Ticket creation can reuse the user's existing explicit authorization; pushing, PR creation and merging remain separate actions.
- Prefix commit messages with the Notion task issue number: `[sc-92] feat: 스터디 목록 빈 상태 화면 추가`.
- Use the same issue-number prefix in the PR title and include the actual Notion issue URL in the PR body. The Notion issue number and GitHub PR number are separate identifiers.
- Keep work branches short-lived and PRs small enough to review and integrate into trunk. One issue may have multiple PRs; link them back to that issue.
- Follow [Feature flag workflow](FEATURE_FLAGS.md) for unfinished features, including behavior and side-effect guards and ON/OFF verification.
- State the PR's completed scope, relevant flag/default, verification evidence, and shared-code impact. PR merge, issue completion, and enabling a feature by default are separate events.
- Preserve issues completed within an agreed Mock scope. Link later API integration or design changes as follow-up issues.

See the [PR template](../../.github/pull_request_template.md) and [AI handoff](AI_HANDOFF.md).

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
- ViewModel tests supply their own repository test double. Test meaningful conversion, response validation and error classification directly; do not add a Client abstraction solely to preserve an isolated Repository test harness.
- Factories may build object graphs but do not expose mutable global state.

## Concurrency and binding

- Repository operations use `async throws`.
- UI-facing ViewModels are `@MainActor`.
- Detail fetches once from init through a private method. Main repeats requests for pagination/refresh with one retained Task and cancelled-result guards. Do not introduce extra lifecycle machinery without a concrete need.
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
- Custom accessibility support is deferred, including accessibility identifiers. Verify native controls manually on Simulator; automated UI tests are not maintained at this stage.

## Errors and copy

- Data maps transport failures into a stable application-facing error surface before Presentation formats user copy.
- User copy explains what happened and the next available action.
- Do not expose raw network or decoding messages in the UI.

## Scoped SwiftUI exception: Development Settings

Only the Debug-only Development Settings screen uses SwiftUI List, Section, Button and Toggle, presented from UIKit via UIHostingController. Its @Observable @MainActor ViewModel is owned with @State by the root SwiftUI view. Use explicit bindings that call model actions; keep UserDefaults and flag reset in Store/ViewModel. Do not use @Published, Combine or @AppStorage for this screen. Other screens continue using UIKit, programmatic layout and private-subject/read-only-publisher observation.
