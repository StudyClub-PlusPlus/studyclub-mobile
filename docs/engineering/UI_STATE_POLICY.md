# UI State Policy

Every asynchronously loaded list or feed must model these states explicitly:

```text
loading -> content(non-empty)
        -> empty
        -> failure
failure --retry--> loading
```

## Rules

- `content` cannot contain an empty collection; an empty result becomes `empty`.
- Loading, background state, and collection content are mutually exclusive.
- Initial load happens once per screen instance unless product policy says otherwise.
- Retry emits loading immediately and starts exactly one new request.
- Cancel or identity-guard the prior task so stale work cannot overwrite a newer result.
- Preserve stable item identifiers across snapshots.
- Select by the diffable item identifier, never a stored array index.
- Failure copy is human-readable and exposes a recovery action when recovery is possible.
- Empty is a valid server result, not an error.

## Future stale-content policy

Detail uses loading, content, and failure without retry. Its six display values live directly on the ViewModel as read-only-to-consumers properties; the private subject publishes only load status after all display fields are updated. Empty topics is valid content. Missing or mismatched study identity is failure. DetailViewModel starts one request from init via private fetchDetail(). No public load method, load flag, Task retention or cancellation is needed. Weak captures allow the ViewModel to be released while the request finishes. CurrentValueSubject replays status to late subscribers.

When cached or paginated content is introduced, define whether refresh failure preserves existing content before implementation. The current mock scaffold has no cache and therefore uses mutually exclusive terminal states.
