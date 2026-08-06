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

- iOS uses UIKit and programmatic Auto Layout.
- The architecture is MVVM + Repository. `R` does not mean Router.
- Swift Concurrency owns asynchronous operations. Combine is limited to ViewModel-to-View observation through a private subject and read-only publisher; do not use `@Published` for this project.
- Source dependencies are `Presentation -> Domain` and `Data -> Domain`. Domain imports no UI, reactive, or networking framework.
- DTOs stay inside Data. Repository protocols return Domain models.
- ViewModels receive dependencies explicitly. Never call `RepositoryFactory` from a ViewModel initializer or default argument.
- `RepositoryFactory` is a composition helper, not a service locator.
- Do not add a UseCase, Router, Coordinator, or generic DI container without a concrete second use case and an architecture decision update.
- Lists and feeds must define loading, content, empty, failure, and retry behavior before implementation.
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
- Async work has cancellation or stale-result protection.
- Accessibility labels, Dynamic Type, safe areas, and 44-point targets are verified.
- Documentation describes the implementation that actually shipped.
- The handoff separates verified evidence, decisions, external unknowns, and uncommitted work.
