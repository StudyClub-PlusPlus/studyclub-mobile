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
- Source dependencies are `Presentation -> Domain` and `Data -> Domain`, with `Presentation -> Data.RepositoryFactory` allowed for repository creation and `Presentation -> Data.DevelopmentSettingsStore` for development configuration. Domain imports no UI, reactive, or networking framework.
- DTOs stay inside Data. Repository protocols return Domain models.
- App-facing ViewModel initializers obtain repositories through `RepositoryFactory`; ViewControllers do not receive or forward repositories. Keep separate repository-injecting initializers for unit tests.
- `RepositoryFactory` selects Repository mode only: Debug follows the persisted Mock/Real choice and Release always uses Real. Feature flags never change that choice. Both configurations apply saved FeatureFlag overrides at the owning Repository/ViewModel/View boundary. Real list OFF makes no API request and shows unavailable; Real detail OFF makes no API request and preserves failure. Mock keeps trusted Domain samples. The real repository creates its API client internally. Do not add mutable global overrides or a generic service locator.
- Do not add a UseCase, Router, Coordinator, or generic DI container without a concrete second use case and an architecture decision update.
- Lists and feeds define loading, content, empty, and failure behavior; Main also distinguishes feature unavailable. Detail treats missing, invalid or mismatched identity as empty. Detail requests once from ViewModel init via a private method. Main captures the list flag at creation: ON supports infinite scrolling, failed-page retry and pull-to-refresh using one retained Task; OFF loads Debug Mock's first page once without pagination, refresh or footer. Cancelled requests must not mutate newer state.
- New feature flags start InProgress with default OFF. After deployment-specific QA, move the same flag to Ready with default ON. After stability is confirmed around a later deployment, remove the flag and its previous else branch together.
- Store fixed views with their default styling in private let initialization closures. configureView handles hierarchy and layout together; updateViews applies display data. ViewControllers use Combine as a notification and read values from the ViewModel.
- Within configureView, group work by view: add the view, configure arranged subviews or relationship-dependent values, and activate its constraints together. Do not split all hierarchy operations and all layout operations into separate phases.
- Collection views use stable identifiers and diffable snapshots. Selection never depends on a stale array index.
- Naming examples in this repository are provisional. Preserve ownership and dependency rules even when names change.

## Change policy

- Before implementation, verify the matching Notion issue and work branch. If the request has no ticket, clarify only missing task details, create or reuse the issue, and prepare its branch first. Use `notion-ticket-branch` when installed; otherwise follow the same workflow in `docs/engineering/CONVENTIONS.md`. Reuse details and ticket-creation authorization already provided by the user.
- Add the smallest feature slice that satisfies the current product contract.
- Keep production API details explicit; do not invent endpoints, auth, or response fields.
- Update relevant docs in the same change when architecture, state policy, or product behavior changes.
- Add or update tests for DTO-to-Domain mapping, response validation, error classification, ViewModel state transitions, selection, and user-visible failure paths. Extract meaningful rules for direct tests; thin Client/Repository wrappers need no isolated unit suite. Add Repository tests when it owns substantial orchestration policy.
- UI changes require a Simulator walkthrough and fresh visual evidence for every changed state.

## Completion checklist

- Project and tests build from the outer monorepo.
- No nested `.git`, `xcuserdata`, secret, or generated build output is tracked.
- New DTOs do not escape Data and new concrete repositories do not leak into Presentation.
- Async work matches its request policy. Detail uses a weak capture without a retained Task. Main uses one retained Task for repeated page/refresh requests and cancelled-result guards, without a request-generation counter.
- Verify safe areas and normal-size interaction manually on Simulator. Automated UI tests are not maintained at this stage; preserve unit tests. Custom accessibility support and dedicated accessibility QA are deferred. Do not add accessibilityIdentifier.
- Documentation describes the implementation that actually shipped.
- The handoff separates verified evidence, decisions, external unknowns, and uncommitted work.
