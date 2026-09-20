# Main and Detail Product Contract

This document is platform-neutral and should be used as the later Android implementation reference.

## Product direction

The evolving product direction and user decisions are recorded in [MOBILE_PRD.md](MOBILE_PRD.md). Exploration is the primary experience, with a guest list entry and a separate planned search/results flow. Web and app own service entry, discovery, application, and management; Discord is the study activity venue.

The sections below describe the existing Main/Detail implementation contract. Planned behavior in the mobile PRD does not change the completion scope of existing Mock work.

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
- study kind, delivery format, capacity, and recruitment status
- study schedule when supplied
- full description
- curriculum when supplied
- standard back navigation

Detail starts loading when its ViewModel is initialized and exposes loading, content, empty, and failure without retry. A missing or mismatched study is empty and shows “스터디를 찾을 수 없어요”. Network and server errors are failure and show a short instruction to return to the previous screen. Nullable cohort, schedule, and description fields do not make the state empty; the remaining detail content is shown. Retry and common ErrorView work are deferred. Detail does not manage request cancellation or request generations: a request may finish after navigating back.

There is no join action, editing, or persistence.

The client and repository expose separate list and detail operations: `fetchStudies()` and `fetchStudy(id:)`. Mock detail lookup uses an independent request. Live detail uses the public web API `GET /api/studies/{studyId}` without authentication. The `study.detail-api` Feature Flag defaults OFF and preserves the Mock path; when enabled, Debug targets Stage and Release targets Production. A 404 is mapped to the empty state. `StudyDetailDTO` stays in Data and maps to the separate `StudyDetail` Domain model; the list DTO is not reused because the server contracts differ.

The current backend detail response does not include the current applicant count, so Detail displays capacity without inventing a current-member value. Thumbnail loading and application actions are outside this issue.

## Mock scenarios

- `content`: a realistic list with multiple distinct items
- `empty`: an empty successful response
- `failure`: every request fails
- `loading`: a deterministic long-running request for state QA
- `detail-failure`, `detail-loading`: list succeeds, detail exercises its own failure or loading lifecycle

The iOS and Android implementations may use different UI frameworks, but state meaning, stable selection behavior, Korean copy intent, and retry policy should remain equivalent.
