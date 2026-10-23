# SC77 상세 계약 복구 · 2026-10-23

- source: `2fff5da4088ad51be38c3c41128eea421dd2306a`, app source tree `0de175c618bcbedde26371753891ab4ba05a0c67`. 이후 증거 파일만 추가한다.
- 기준: main `6230f535`(auth23 + 검색 플래그74). Xcode27.0(27A266a), Debug Real, bundle `studycub.studyclub`.
- 재사용 iPhone17e / iOS26.5 / `8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1`. 단일 writer, `-parallel-testing-enabled NO`를 명시했다.
- `StudyDetailContractTests`, `StudyDetailMapperTests`, `DetailViewModelTests`: **18/18 통과, 실패0**, [원시 summary](tests-summary.json). xcresult는 `/tmp/studyclub-search-r1/sc77-focused.xcresult`에 둔다.
- 설치 Debug app의 `studyclub.debug.dylib` SHA256: `8d0d4315a3471ca4f98cfc7e75b797ed18d6ac41d9cd679a8f718901589adb7e`.

## 원인과 복구

서버 [main61d46fb1 StudyDetailResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/61d46fb1d78a7b4744cb4aaa40c07ebfbc8791e7/backend/api/src/main/java/com/studyclub/api/study/StudyDetailResponse.java)에 deliveryFormat이 없다. 2026-10-23T12:24:09Z 공개 `/api/studies/86` HTTP200 응답을 기존 DTO에 넣으면 keyNotFound(deliveryFormat)였다. 같은 응답을 이번 DTO로 디코딩하면 `decoded id=86 title=로봇 AI format=nil`이다. 공개 응답·스크립트는 `/tmp/studyclub-search-r1/`에 보존했다.

동일 테스트 설치 후보를 평상시 앱으로 실행하고 실제 공개 목록의 “르네상스 클럽”을 눌렀다. 이전의 빈 상세 대신 제목·설명·모임·모집 상태가 표시됐으며 임의 온라인 문구는 없었다. [실제 상세 캡처](real-detail-without-format.png). UIKit 앱의 공개 Alamofire→DTO→Mapper→ViewModel→Detail 경로다.

이 단독 후보에는 검색 화면이 없다. 종료 검색 결과(ID86)의 통합 화면 이동은 SC76 통합 후보에서 별도 확인한다. Mock 데이터나 소스 읽기만으로 실제 상세 경로를 통과 처리하지 않았다.
