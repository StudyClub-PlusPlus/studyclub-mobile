# StudyClub Mobile Agent Guide

This file is the entry point for AI-assisted work in this repository.

## Read first

Before changing iOS code, read:

1. `docs/engineering/ARCHITECTURE.md`
2. `docs/engineering/CONVENTIONS.md`
3. `docs/engineering/UI_STATE_POLICY.md`
4. `docs/engineering/TESTING.md`
5. `docs/engineering/AI_HANDOFF.md`
6. `DESIGN.md` for UI work
7. the relevant contract under `docs/product/`

## Stable constraints

- iOS uses UIKit and programmatic Auto Layout. The Debug-only Development Settings screen is a scoped exception: SwiftUI hosted by UIHostingController.
- The architecture is MVVM + Repository. `R` does not mean Router.
- Swift Concurrency owns asynchronous operations. UIKit ViewModels use Combine only for ViewModel-to-View observation through a private subject and read-only publisher; do not use `@Published`. Development Settings alone uses an `@Observable` ViewModel, owned by SwiftUI `@State`; persistence stays in Store/ViewModel.
- Source dependencies are `Presentation -> Domain` and `Data -> Domain`, with `Presentation -> Data.RepositoryFactory` allowed for repository creation. Domain imports no UI, reactive, or networking framework.
- DTOs stay inside Data. Repository protocols return Domain models.
- App-facing ViewModel initializers obtain repositories through `RepositoryFactory`; ViewControllers do not receive or forward repositories. Keep separate repository-injecting initializers for unit tests.
- `RepositoryFactory` owns repository/client construction. Do not add mutable global overrides or a generic service locator.
- Do not add a UseCase, Router, Coordinator, or generic DI container without a concrete second use case and an architecture decision update.
- Lists and feeds define loading, content, empty, and failure behavior. Current screens request once from ViewModel init via a private fetch method; retry, refresh, and Task management are deferred until needed.
- Store fixed views with their default styling in private let initialization closures. configureView handles hierarchy and layout together; updateViews applies display data. ViewControllers use Combine as a notification and read values from the ViewModel.
- Within configureView, group work by view: add the view, configure arranged subviews or relationship-dependent values, and activate its constraints together. Do not split all hierarchy operations and all layout operations into separate phases.
- Collection views use stable identifiers and diffable snapshots. Selection never depends on a stale array index.
- Naming examples in this repository are provisional. Preserve ownership and dependency rules even when names change.

## Change policy

- Add the smallest feature slice that satisfies the current product contract.
- Keep production API details explicit; do not invent endpoints, auth, or response fields.
- Update relevant docs in the same change when architecture, state policy, or product behavior changes.
- Add or update tests for mapper, repository, ViewModel state transitions, selection, and user-visible failure paths.
- UI changes require a Simulator walkthrough and fresh visual evidence for every changed state.

## Completion checklist

- Project and tests build from the outer monorepo.
- No nested `.git`, `xcuserdata`, secret, or generated build output is tracked.
- New DTOs do not escape Data and new concrete repositories do not leak into Presentation.
- Async work matches its request policy. Current one-request ViewModels use weak captures and need no retained Task or request-generation counter; revisit concurrency protection when adding repeated requests.
- Accessibility labels, Dynamic Type, safe areas, and 44-point targets are verified.
- Documentation describes the implementation that actually shipped.
- The handoff separates verified evidence, decisions, external unknowns, and uncommitted work.
