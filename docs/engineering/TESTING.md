# Testing Policy

## Unit tests

- DTO-to-Domain mapping, including optional/default handling and invalid member counts
- repository success, empty, error propagation, cancellation behavior, and duplicate identifier rejection
- ViewModel initialization triggers one request; loading-to-content/empty/failure transitions
- Display values are ready before notification and available to late subscribers
- display formatting that contains non-trivial policy

Test doubles are injected through protocols. Tests must not call the static factory from the system under test.

## UI tests

Mock behavior is selected with deterministic launch arguments:

- `--mock-scenario content`
- `--mock-scenario empty`
- `--mock-scenario failure`
- `--mock-scenario loading`
- `--mock-scenario detail-failure`
- `--mock-scenario detail-loading`

Required smoke flows:

1. Content launches and the second study opens the matching Detail.
2. Empty state renders without cells.
3. Main failure and empty states expose no retry/reload action.
4. Loading remains visible while a deterministic long-running request is active.
5. Detail failure has no retry button; both failure and loading allow back navigation.
6. Main and Detail screenshots are retained in XCTest result attachments.

## Verification order

1. Resolve packages and build.
2. Run unit tests.
3. Run focused UI tests on a named Simulator.
4. Walk all product states manually.
5. Capture fresh screenshots and run independent visual/code review.

Do not report a build, test, or visual pass from output produced before the last relevant source edit.
