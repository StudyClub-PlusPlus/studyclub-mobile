# API integration status

sc-145 removes API Client Mock/scenario support and UI tests. Debug sample output comes from a Domain-model MockRepository selected through Development Settings. The merged [detail integration PR #1 (sc-93)](https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/1), included in main `c2fea74614f96210f8b9c01e32a12b389d7e84c9`, is preserved in the rebased sc-145 source. List API integration remains a separate task.

## Current detail implementation

StudyRouter owns the fixed Production BaseURL `https://api.studyclub-plusplus.com/api/`. Concrete StudyAPIClient calls `AF.request(StudyRouter.study(id:))`, validates the response and decodes the flat StudyDetailDTO for public `GET /api/studies/{studyId}` without authentication. The DTO maps to the separate StudyDetail Domain model. The current 11 categories, five lifecycle statuses, nullable recruitment status and optional description/curriculum/schedule fields follow sc-93's backend contract. No current-member count is invented for Detail.

Repository preserves cancellation and Domain errors, maps HTTP 404 to notFound and decoding failures to invalidData, and maps other failures to unavailable. The mapper validates positive ID/capacity, nonempty title and supplied dates; Repository checks the requested identity. DetailViewModel maps notFound, invalidData and mismatched identity to empty, and network/server errors to failure.

The Ready `study.detail-api` flag is retained. Debug OFF selects MockRepository; Debug ON follows the persisted Mock/Real mode (default Mock). Release always creates the real Repository and ignores saved Debug mode/flag overrides. MockRepository returns trusted Study list and matching StudyDetail samples with numeric IDs, with no DTOs, delay or transport scenarios. There is no Client protocol, Client/Session injection or per-operation closure injection. Stage selection is not maintained; no automatic environment fallback is added.

Opt-in LiveStudyDetailTests construct Repository() and require STUDYCLUB_LIVE_API_BASE_URL to equal the Production URL; missing opt-in or another URL skips with a reason. Preserved [sc-93 evidence](../evidence/sc-93-live/README.md) describes its earlier candidate and is historical, not current validation of the rebase. This integration was source-reviewed only during the rebase; fresh build, serial tests and actual-path QA belong to the lead and independent QA.

## Remaining list integration gap

On 2026-10-01, the public Production `GET /api/studies` returned HTTP 200 with an `items`/`total`/`offset`/`limit` envelope. Items used numeric `studyId`, `oneLineSummary`, nullable `capacity` and `currentApplicants`. Stage DNS did not resolve from the development machine. These are historical observations, not a current availability guarantee.

The list client still expects a top-level [StudyDTO] with String `id`, `summary`, `currentMembers`, positive `maximumMembers` and mock-era status values. A prior development check with the actual response and JSONDecoder reproduced an array/object type mismatch; decoding one item separately reproduced a missing `id` error. sc-93 did not integrate the list contract, so ordinary Real-mode Main navigation remains blocked by that gap. Debug Mock list-to-detail stays available; a successful live detail check does not prove live list navigation.

The recorded engineering references are [StudyListResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/c034e6d0ee54d4bc03afcd345ee3e596e766f717/backend/api/src/main/java/com/studyclub/api/study/StudyListResponse.java) and [StudyDetailResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/c034e6d0ee54d4bc03afcd345ee3e596e766f717/backend/api/src/main/java/com/studyclub/api/study/StudyDetailResponse.java); current detail specifics and later Production verification are recorded in the sc-93 evidence. List member/status meanings need an explicit Domain/display mapping; do not fabricate counts or interpret applicant count as member count. Future integration must verify actual response decoding and the resulting app path; Client unit tests are not a substitute.
