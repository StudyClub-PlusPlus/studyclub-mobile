# Coding Conventions

Use [the engineering index](INDEX.md) to load the rules for the current task. This file contains source-level conventions shared by iOS changes.

## Naming and model flow

| Role | Pattern | Example |
|---|---|---|
| Server parsing model | `*DTO` | `StudyDTO` |
| Application model | noun | `Study` |
| Cell display model | `*CellViewModel` | `StudyCardCellViewModel` |
| Screen load state | nested `LoadState` | `DetailViewModel.LoadState` |
| Repository implementation | `Repository` / `MockRepository` | `Repository` |
| Composition helper | `*Factory` | `RepositoryFactory` |

Names may change when they improve clarity. Keep ownership and dependency direction unchanged. Avoid mechanical names such as `RepositoryImpl`, `ServerModel`, and `ClientModel` when a role-specific name is clearer.

The data flow is `DTO -> Domain model -> ViewModel display values`. Data maps server values to Domain models. Presentation formats Domain meaning for display and keeps screen state in the owning ViewModel. A cell ViewModel is immutable display data; it does not need a repository, publisher, or reference semantics.

## Repository construction

- App-facing ViewModel initializers obtain the shared Study repository through `RepositoryFactory`.
- ViewControllers do not receive or forward repositories.
- Keep a separate initializer that accepts a Domain repository protocol for deterministic unit tests.
- Factories build object graphs; they do not expose mutable global state.
- Keep DTOs and concrete repository construction inside Data.

## Error and copy ownership

- Data maps transport and decoding failures to stable Domain-facing errors.
- Presentation chooses user-facing copy and the next action from those errors.
- Never display raw networking or decoding messages.
- Test response validation and error classification at the layer that owns each rule.

## Issues, commits, and pull requests

Follow [the task workflow](TASK_WORKFLOW.md) for issue scope, branch, commit, and PR rules. Follow [AI handoff](AI_HANDOFF.md) for evidence and completion reporting.
