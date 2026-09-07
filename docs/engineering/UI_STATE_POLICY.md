# UI State Policy

Main models loading, content, empty, and failure explicitly. Detail models loading, content, and failure; zero topics is valid detail content.

- MainViewModel and DetailViewModel each start one request from init through a private fetch method.
- No public load method, retry, refresh, request generation counter, or ViewModel Task cancellation is needed in this slice.
- Tasks capture their ViewModel weakly. Requests may finish after the screen is closed.
- Future retry and shared ErrorView work must define overlapping-request and cancellation policy when introduced.
- ViewModels store display values before publishing a status notification through a private CurrentValueSubject and read-only publisher.
- ViewControllers use notifications to call updateViews(), which reads the ViewModel's current values. CurrentValueSubject replays status to late subscribers.
- Loading, content, empty, and failure surfaces are mutually exclusive.
- Main content requires non-empty items. Empty is a valid successful response.
- Select by stable diffable item identifier, never a stored array index. Missing or mismatched detail identity is failure.
- Failure ends loading and shows human-readable copy; no retry or reload controls are offered yet.

## Future stale-content policy

If refresh, caching, pagination, or retry is added, decide how existing content and overlapping requests behave before implementation.
