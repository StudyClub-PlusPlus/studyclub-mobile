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

When cached or paginated content is introduced, define whether refresh failure preserves existing content before implementation. The current mock scaffold has no cache and therefore uses mutually exclusive terminal states.
