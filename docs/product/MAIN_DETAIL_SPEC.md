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
- Failure: the request failed and the user can retry.

Selecting an item opens Detail for that exact stable ID and content. The selected item is the source for the first Detail version; Detail does not refetch.

## Detail

Detail presents:

- category and title
- current/max member count and status
- full summary
- learning topics
- standard back navigation

The first version has no join action, editing, persistence, or independent network lifecycle.

## Mock scenarios

- `content`: a realistic list with multiple distinct items
- `empty`: an empty successful response
- `failure`: every request fails
- `failure-once`: the first request fails and retry succeeds
- `loading`: a deterministic long-running request for state and accessibility QA

The iOS and Android implementations may use different UI frameworks, but state meaning, stable selection behavior, Korean copy intent, and retry policy should remain equivalent.
