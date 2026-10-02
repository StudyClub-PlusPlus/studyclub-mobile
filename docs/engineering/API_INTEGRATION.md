# API integration status

API Client Mock/scenario support was removed under sc-145; Debug sample output now comes from a Domain-model MockRepository selected through Development Settings. The user confirmed that sc-93 API integration is owned by another contributor. sc-145 prepares the code and test boundaries; endpoint, DTO and display-contract integration belongs to sc-93.

The existing [detail integration PR #1 (sc-93)](https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/1) supplies Stage `https://api.stage.studyclub-plusplus.com/api/` and Production `https://api.studyclub-plusplus.com/api/` base URLs. Its head inspected for this work was `e8ae365d86d4b120b196b07c96926d198fdea2e5`; it has not been imported into sc-145.

On 2026-10-01, the public Production `GET /api/studies` returned HTTP 200 with an `items`/`total`/`offset`/`limit` envelope. Items use numeric `studyId`, `oneLineSummary`, nullable `capacity` and `currentApplicants`. Stage DNS did not resolve from the development machine. These observations are not a service availability guarantee.

The existing mobile client expects a top-level `[StudyDTO]` with String `id`, `summary`, `currentMembers`, positive `maximumMembers` and mock-era status values. A development check with the actual response and current `JSONDecoder` reproduced an array/object type mismatch; decoding one item separately reproduced a missing `id` error. A BaseURL substitution alone cannot make the list work.

The current engineering contract is in [StudyListResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/c034e6d0ee54d4bc03afcd345ee3e596e766f717/backend/api/src/main/java/com/studyclub/api/study/StudyListResponse.java) and [StudyDetailResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/c034e6d0ee54d4bc03afcd345ee3e596e766f717/backend/api/src/main/java/com/studyclub/api/study/StudyDetailResponse.java). Its member and status meanings require an explicit Domain/display mapping; do not fabricate counts or interpret applicant count as member count.

Until that integration is implemented, the app retains the temporary `.invalid` BaseURL and the explicit `detailAPIUnconfigured` error. Release and Debug Real mode show Main failure; Debug Mock mode shows sample content and matching sample details. Integration work must verify actual DTO decoding and the resulting app path before commit; Client unit tests are not a substitute.
