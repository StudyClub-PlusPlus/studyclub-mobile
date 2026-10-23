# Concurrency rules

Read [Architecture](ARCHITECTURE.md) for layer ownership and [UI state policy](UI_STATE_POLICY.md) for user-visible state transitions.

## Async boundaries

- Use Swift Concurrency for asynchronous operations. Repository protocols expose `async throws` functions and conform to `Sendable`.
- UI-facing ViewModels are `@MainActor`. Repository and client methods run outside the caller's actor under the project's Swift compiler settings.
- Domain values that cross actor boundaries conform to `Sendable` where practical. `StudyAPIClient` is `Sendable`; Alamofire's `URLRequestConvertible` supplies `Sendable` for `StudyRouter`.
- UIKit ViewModels use Combine only to notify views. Keep mutable state in a private `CurrentValueSubject` and expose a read-only publisher. Combine does not replace async networking.
- `DefaultAuthRepository` owns credential state, refresh, and invalidation. Repositories may request a scoped authorization operation from it. Tokens stay in Data.

## Request lifetime

- Detail starts one request from ViewModel initialization through a private method. It does not retain a `Task`; use a weak capture and ignore cancelled completion.
- Main uses one retained `Task` for initial load, pagination, and refresh. Cancel old work when replacing it and guard cancelled results before changing state. Do not add a request-generation counter.
- A cancellation must not change the state produced by a newer request.
- Search owns one retained Task for debounce or a page request. Input deletion, composition, filter replacement and search dismissal cancel it and clear its cursor. The 300ms sleep implements the product's input debounce; it is not an ordering probe. Success and failure both check Task cancellation before changing any state, including the task handle. Tests suspend repository responses explicitly instead of sleeping.
- Account invalidation is awaited by the feature owner. Do not swallow cleanup failures with `try?` or report cancellation as success when invalidation failed.
- Do not add timers, sleeps, detached tasks, or lifecycle machinery to solve request ordering. Use deterministic continuations in tests.

The project explicitly disables `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT` in Debug and Release. Do not infer actor behavior from defaults that differ from this setting.
