# UIKit rules

UIKit and programmatic Auto Layout are the default for app screens. Read [Architecture](ARCHITECTURE.md) for dependency boundaries, [Concurrency](CONCURRENCY.md) for ViewModel binding, and [Design](../../DESIGN.md) for visual tokens and screenshot acceptance.

- Build view hierarchies in code. Set `translatesAutoresizingMaskIntoConstraints = false` explicitly.
- Use semantic colors, preferred fonts, safe areas, and self-sizing layouts. Keep shared visual constants in `AppTheme`.
- Store fixed views as `private let` properties with their fixed styling in initialization closures. Data-driven rows may use a local factory.
- `configureView()` builds hierarchy and layout together. For each view, add it, configure its relationships or arranged subviews and custom spacing, then activate its constraints before moving to the next view. Keep a child's explicit size constraints next to its addition.
- Activate cross-view constraints only after the views have a common ancestor. Preserve visual stacking order.
- `updateViews()` reads display values from the ViewModel after a Combine notification. Update all displayed values before publishing the notification.
- ViewControllers own UIKit lifecycle and immediate navigation. Do not add a Router or Coordinator without reusable multi-step branching or an ownership problem.
- Do not add `accessibilityIdentifier`. Dedicated accessibility implementation and QA remain deferred. Use native controls and verify interaction manually on Simulator.
