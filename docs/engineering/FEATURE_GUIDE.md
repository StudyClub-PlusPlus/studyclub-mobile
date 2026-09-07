# Adding an iOS Feature

1. Write or update the product state and navigation contract under `docs/product/`.
2. Add Domain models and repository methods only for stable application meaning.
3. Add DTOs, mappers, clients, and repository implementation changes inside Data.
4. Add Presentation ViewState, ViewModel, UIKit view/controller, and accessibility identifiers.
5. Obtain repositories through RepositoryFactory in app-facing ViewModel initializers; keep protocol-injecting initializers for unit tests.
6. Add loading/content/empty/failure/retry policy for every async list or feed.
7. Add mapper, repository, ViewModel, and user-flow tests.
8. Update architecture or convention docs if a dependency rule changes.
9. Build, test, run the Simulator flow, and review fresh visual evidence.

Before introducing a new abstraction, name the repeated problem it solves and at least two concrete consumers. Otherwise keep the implementation explicit.
