# Engineering document index

Start here after reading the root [AGENTS.md](../../AGENTS.md). Open only the documents listed for the work you will change. Add a document to a task's reading set only when its rules affect that change.

| Work | Required context | Read when relevant |
|---|---|---|
| Any iOS source change | [Architecture](ARCHITECTURE.md), [Coding conventions](CONVENTIONS.md) | Product contract and feature docs |
| Repository, API, DTO, mapping | Architecture, [API integration](API_INTEGRATION.md), [Testing](TESTING.md) | `docs/product/*_API*.md` for the endpoint contract; [Concurrency](CONCURRENCY.md) for async calls |
| ViewModel or async request behavior | Architecture, [Concurrency](CONCURRENCY.md), [UI state policy](UI_STATE_POLICY.md), Testing | Product contract for the screen |
| UIKit screen or navigation | Architecture, [UIKit rules](UIKIT.md), [Design system](../../DESIGN.md) | UI state policy; product screen contract |
| SwiftUI Development Settings | Architecture, [SwiftUI rules](SWIFTUI.md), [Feature flags](FEATURE_FLAGS.md) | Development Settings product spec |
| Feature flag change | Architecture, Feature flags, UI state policy | API integration or product contract |
| New feature slice | Architecture, Coding conventions, [Feature guide](FEATURE_GUIDE.md), Task workflow | Only the relevant screen, API, flag, and state documents |
| Login or signup View | Architecture, [Login View](LOGIN_VIEW.md), UIKit, Design | Login product/API contract |
| Tests or verification | [Testing](TESTING.md) | [Simulator storage policy](SIMULATOR_TESTING.md) when running XCTest; concurrency/UI state policy for affected behavior |
| Task, issue, commit, or PR | [Task workflow](TASK_WORKFLOW.md), [AI handoff](AI_HANDOFF.md) | Product/design/API contract for the deliverable |

## Document ownership

- `ARCHITECTURE.md`: layers, dependencies, repository boundary, composition, and abstraction criteria.
- `CONVENTIONS.md`: naming, model flow, error ownership, and repository initialization conventions.
- `SWIFTUI.md`: the single SwiftUI exception and Observation rules.
- `CONCURRENCY.md`: async boundaries, cancellation, task lifetime, and actor ownership.
- `UIKIT.md`: UIKit construction, layout, binding, and navigation rules.
- `UI_STATE_POLICY.md`: user-visible screen states and per-screen request policy.
- `FEATURE_FLAGS.md`: stages, defaults, overrides, and release progression.
- `API_INTEGRATION.md`: API-specific implementation and dated integration evidence. The product API document remains the contract source.
- `TESTING.md`: unit-test scope, serial simulator policy, and manual checks.
- `SIMULATOR_TESTING.md`: simulator cloning, retained storage, and cleanup limits.
- `TASK_WORKFLOW.md` and `AI_HANDOFF.md`: work setup and evidence handoff.

Keep one rule in its owning document. Link to it elsewhere instead of copying it. Keep feature behavior in `docs/product/` and dated candidate evidence in `docs/evidence/`.
