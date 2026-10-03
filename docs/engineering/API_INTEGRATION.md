# API integration status

sc-145 removes API Client Mock/scenario support and UI tests. Debug sample output comes from a Domain-model MockRepository selected through Development Settings. The merged [detail integration PR #1 (sc-93)](https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/1), included in main `c2fea74614f96210f8b9c01e32a12b389d7e84c9`, is preserved in the rebased sc-145 source. sc-92 connects the paged recruiting list below.

## Current detail implementation

StudyRouter owns the fixed Production BaseURL `https://api.studyclub-plusplus.com/api/`. Concrete StudyAPIClient calls `AF.request(StudyRouter.study(id:))`, validates the response and decodes the flat StudyDetailDTO for public `GET /api/studies/{studyId}` without authentication. The DTO maps to the separate StudyDetail Domain model. The current 11 categories, five lifecycle statuses, nullable recruitment status and optional description/curriculum/schedule fields follow sc-93's backend contract. No current-member count is invented for Detail.

Repository preserves cancellation and Domain errors, maps HTTP 404 to notFound and decoding failures to invalidData, and maps other failures to unavailable. The mapper validates positive ID/capacity, nonempty title and supplied dates; Repository checks the requested identity. DetailViewModel maps notFound, invalidData and mismatched identity to empty, and network/server errors to failure.

The Ready `study.detail-api` flag is retained. OFF selects MockRepository in both configurations. ON follows the persisted Mock/Real mode in Debug (default Mock), while Release uses Real. Both configurations apply saved FeatureFlag overrides; only Repository mode and the developer entry differ. MockRepository returns trusted Study list and matching StudyDetail samples with numeric IDs, with no DTOs, delay or transport scenarios. There is no Client protocol, Client/Session injection or per-operation closure injection. Stage selection is not maintained; no automatic environment fallback is added.

Opt-in LiveStudyDetailTests construct Repository() and require STUDYCLUB_LIVE_API_BASE_URL to equal the Production URL; missing opt-in or another URL skips with a reason. Preserved [sc-93 evidence](../evidence/sc-93-live/README.md) describes its earlier candidate and is historical, not current validation of the rebase. This integration was source-reviewed only during the rebase; fresh build, serial tests and actual-path QA belong to the lead and independent QA.

## Recruiting list implementation (sc-92)

`GET /api/studies?status=RECRUITING&offset=0&limit=20` uses the fixed Production URL. Router/Client accept offset and limit; Repository fixes limit to 20 and returns Domain StudyPage. The latest fixed source `94eb15f13c4b561e0d84ba77085c336365b25dad` uses flat items in a page object, with numeric studyId and phase (RECRUITING/ONGOING/CLOSED). Earlier OPEN/cohort notes are historical.

The list DTO reads only used fields: studyId, category, title, oneLineSummary, currentApplicants, nullable capacity, phase and closingSoon; page metadata uses Int. Slug, images and unused fields are omitted. Mapper converts positive numeric ID to String Study.ID and preserves nullable capacity. currentApplicants counts ACTIVE/PAUSED participants, not application forms. Count above capacity is not inherently invalid. Domain values are formatted in Presentation.

InProgress `study.list-api` defaults OFF. Both Debug and Release apply stored overrides. OFF uses trusted Domain samples without transport; ON selects Debug saved Repository mode or Release Real. No new flag catalog/Client protocol/Session injection is introduced. Detail keeps its independent flag and ID lookup.

Main owns one Task for initial page, automatic additional pages and pull-to-refresh. Content and cursor survive failed page/refresh requests. Cancelled old tasks cannot overwrite a refreshed list or stop its indicator. Same-ID cards are reconfigured and empty snapshots clear stale selection. See [list design](../product/STUDY_LIST_API_DESIGN.md) and [UI state policy](UI_STATE_POLICY.md).

Opt-in LiveStudyListTests construct Repository directly and check actual page decoding and selected-ID detail lookup. Mapper, page/error helpers and Main state tests remain separate. Automated UI tests, JSON fixtures and thin transport doubles are not added. A source change or green test does not prove manual scrolling/rendering; fresh evidence for this candidate is reported separately.
