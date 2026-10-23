# StudyClub Mobile Agent Guide

This file is the short entry point for AI-assisted work in this repository.

## Before work

1. Read this file.
2. Open [the engineering index](docs/engineering/INDEX.md).
3. Read the documents listed for the task. Do not load unrelated engineering or feature documents.
4. Read the relevant product/API contract. For UI work, also read `DESIGN.md`.
5. Before implementation, verify the matching Notion issue and work branch. If no issue exists, create or reuse one and prepare its branch first. Use the installed `notion-ticket-branch` workflow when available; otherwise follow `docs/engineering/TASK_WORKFLOW.md`.

## Stable boundaries

- iOS uses UIKit and programmatic Auto Layout. Only Debug Development Settings uses SwiftUI hosted by `UIHostingController`.
- The architecture is MVVM + Repository. `R` does not mean Router.
- `RepositoryFactory` selects Mock or Real mode only. Debug follows the saved mode; Release always uses Real. Feature flags never select a repository type.
- `RepositoryProtocol` and `Repository` are the single Study repository boundary for recruiting studies, details, and a member's studies. `AuthRepository` separately owns authentication and credentials. Do not add parallel Study repositories, routers, mutable global overrides, or a generic service locator.
- DTOs stay in Data. Repository protocols return Domain models. Domain imports no UI, reactive, or networking framework.
- App-facing ViewModels obtain repositories through `RepositoryFactory`. ViewControllers do not receive or forward repositories. Keep protocol-injecting initializers for unit tests.
- Feature flags start InProgress and default OFF. Move a flag to Ready/default ON only after deployment-specific QA. Remove a stable flag and its previous branch together after a later deployment.
- Lists and feeds define loading, content, empty, and failure behavior. Detail treats missing, invalid, or mismatched identity as empty. Main and Detail retain their documented request policies; see the indexed UI state and concurrency rules.
- Do not add a UseCase, Router, Coordinator, or generic DI container without a concrete second use case and an architecture decision update.

## Change and completion

- Make the smallest feature slice that satisfies the current product contract. Do not invent endpoints, authentication behavior, or response fields.
- Update the owning documentation when architecture, state policy, API behavior, or product behavior changes.
- Add tests for meaningful mappings, response validation, error classification, ViewModel transitions, selection, and user-visible failure paths. Thin Client/Repository wrappers need no isolated unit suite.
- UI changes require a Simulator walkthrough and fresh visual evidence for each changed state. Automated UI tests are not maintained at this stage.
- Do not add accessibility identifiers.
- Build the project and tests from the outer monorepo. Do not track nested `.git`, `xcuserdata`, secrets, or generated build output.
- The handoff separates verified evidence, decisions, external unknowns, and uncommitted work.

For Simulator testing, follow the iOS Simulator Storage Guardrail supplied in the task instructions and the serial XCTest policy in [Testing](docs/engineering/TESTING.md).
