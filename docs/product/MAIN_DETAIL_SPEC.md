# Main and Detail Product Contract

This document is platform-neutral and should be used as the later Android implementation reference.

## Main

Main shows the currently available study groups as a vertically scrolling list.

Each item exposes:

- stable study ID
- category
- title
- short summary
- current and maximum member count
- status text
- topics or learning goals needed by Detail

Main states:

- Loading: request is in progress.
- Content: at least one study is visible.
- Empty: the request succeeded with no study.
- Failure: the request failed; error copy is shown without retry.

Main starts one request from ViewModel init. Its items are stored on the ViewModel; Combine publishes status notifications after display data is ready. Retry, refresh, and Task cancellation management are deferred.

Selecting an item opens Detail for that exact stable ID. Detail fetches independently by ID; the list payload is not its content source.

## Detail

Detail presents:

- category and title
- current/max member count and status
- full summary
- learning topics
- standard back navigation

Detail starts loading when its ViewModel is initialized and exposes loading, content, and failure without retry. Failure ends loading and shows a short instruction to return to the previous screen. Retry and common ErrorView work are deferred. Detail does not manage request cancellation or request generations: a request may finish after navigating back. An unknown or mismatched ID is a failure; zero topics is valid content.

There is no join action, editing, or persistence.

The client and repository expose separate list and detail operations: `fetchStudies()` and `fetchStudy(id:)`. Mock detail lookup uses an independent request and the existing sample fields. Production detail URL, authentication and response schema are unknown: the live client explicitly throws `detailAPIUnconfigured` until those are provided. Separate StudyList/StudyDetail DTO shapes should follow the actual API contract rather than guessed fields.

## Mock scenarios

- `content`: a realistic list with multiple distinct items
- `empty`: an empty successful response
- `failure`: every request fails
- `loading`: a deterministic long-running request for state QA
- `detail-failure`, `detail-loading`: list succeeds, detail exercises its own failure or loading lifecycle

The iOS and Android implementations may use different UI frameworks, but state meaning, stable selection behavior, Korean copy intent, and retry policy should remain equivalent.
