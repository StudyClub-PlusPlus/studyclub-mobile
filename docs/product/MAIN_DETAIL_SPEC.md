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

Main states:

- Loading: request is in progress.
- Content: at least one study is visible.
- Empty: the request succeeded with no study.
- Failure: the request failed; error copy is shown without retry.

Main requests a recruiting page from init, loads more automatically near the end, and supports native pull-to-refresh. One stored Task cancels and suppresses older results. Page failures keep content with same-offset retry. See STUDY_LIST_API_DESIGN.md for the current contract.

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

The client and repository expose separate list and detail operations: `fetchStudies(offset:)` and `fetchStudy(id:)`. Mock detail lookup uses an independent request. Live detail uses the public web API `GET /api/studies/{studyId}` without authentication. The Ready `study.detail-api` Feature Flag defaults ON. OFF uses MockRepository. List-OFF also keeps sample-ID details in the sample catalog. ON follows saved Mock/Real in Debug and Real in Release. Release uses Real for enabled features and reads the same saved FeatureFlag overrides as Debug. Real detail targets the public Production API. A 404 is mapped to the empty state. `StudyDetailDTO` stays in Data and maps to the separate `StudyDetail` Domain model; the list DTO is not reused because the server contracts differ.

The current backend detail response does not include the current applicant count, so Detail displays capacity without inventing a current-member value. Thumbnail loading and application actions are outside this issue.

## State verification

ViewModel unit tests inject Mock repositories returning Domain models to exercise content, empty and failure. They verify loading before completion and consistent display values after completion. DTO-to-Study/StudyDetail mapping, response identity validation and error/cancellation classification are tested directly as extracted rules. The concrete Repository connects these rules; its API integration is verified by the developer during integration work. Test scenarios do not enter app code.

The iOS and Android implementations may use different UI frameworks, but state meaning, stable selection behavior, Korean copy intent, and retry policy should remain equivalent.


## Current public detail API integration

The backend Controller and StudyDetailResponse source, plus deployed Production responses, are the contract reference; the old get-single-study-contract.md describes a different historical response shape. Detail decodes a flat response, uses the current 11-category enum and five lifecycle statuses, and accepts null recruitStatus (omitting that display segment). Numeric ID is the only identity check; server slug and private links are not used.

The detail flag is Ready (default ON). Persisted overrides are read in both Debug and Release. Repository mode still controls Mock/Real and keeps its existing Mock default. Real detail calls the public Production endpoint; there is no automatic fallback to Mock or Production on a Stage failure. StudyRouter owns the fixed Production BaseURL; Client/Session injection and Stage selection are not maintained. sc-92 connects the live paged list behind study.list-api. Sample list IDs stay in the sample detail catalog while the list flag is OFF; live list-to-detail requires both API flags ON.

Actual endpoint decoding and the installed list-to-detail path are checked during API development and recorded as dated evidence. Production-dependent XCTest cases and fixed live IDs are not maintained; unit tests use deterministic Domain inputs. Historical live-test evidence applies only to its recorded candidate.
