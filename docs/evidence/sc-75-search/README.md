# SC75 공개 검색 계약 확인 · 2026-10-23

## 새 main 기준 후보

main `6230f535`(auth23 + SC74) 위 source `df06193298f2119557b2333d0d4054d1cb0771aa`, app source tree `42fe2bbf8d7d29816a1b88034a10d1ccf57f7a65`에서 Xcode27.0 Debug build 및 iPhone17e/iOS26.5 직렬 XCTest를 실행했다. `-parallel-testing-enabled NO`를 명시한 Router/SearchRepository **7/7 통과, 실패0**는 [원시 summary](tests-summary.json)에 있다. 이후 이 증거 파일만 추가한다. API 변경 파일은 앞선 source6ca8a66과 동일하며 auth 병합으로 검색 요청 계약을 바꾸지 않았다.

추가 실제 probe: `2026-10-23T11:59:50Z` keyword=스터디,status=CLOSED,category=SOFTWARE → HTTP200 / decoded7,total7,CLOSED. `2026-10-23T12:00:35Z` keyword=스터디,offset20 → HTTP200 / decoded18,total38,offset20. 같은 현재 DTO/Mapper로 디코딩했다. SC76 선행 source953d735의 native Real 화면에서도 동일 검색 API 코드로 빈 검색어 초기·Swift0건·스터디 결과·종료 필터가 관측됐다. 그 UI 관측은 해당 선행 후보의 증거이며 이 독립 API 후보의 화면 완료를 뜻하지 않는다.

## 최초 계약 확인

- 모바일 기준: cf57fab + SC74(d0431ec), 이번 SC75 변경. 이 문서는 Simulator 결과가 아니다.
- 서버 원문: studyclub-engineering origin/main `61d46fb1d78a7b4744cb4aaa40c07ebfbc8791e7`. Controller/DAO/StudyCategory를 git object로 읽었다.
- 공개 `GET https://api.studyclub-plusplus.com/api/studies?keyword=Swift&offset=0&limit=20`: HTTP 200, items 0 / total 0.
- 공개 `keyword=스터디&offset=0&limit=20`: HTTP 200, items 20 / total 38 / offset 0. Authorization 헤더를 보내지 않았다. 응답에는 RECRUITING/ONGOING/CLOSED가 있었다.
- 이번 후보의 `StudyDTO.swift`, `StudyMapper.swift`, Domain Study/StudyCategory/StudyPhase를 임시 Swift 스크립트에 그대로 이어 붙여 실제 응답을 JSONDecoder로 디코딩하고 toDomain()을 호출했다. 결과: `decoded_count=20 total=38 offset=0 phases=["CLOSED", "ONGOING", "RECRUITING"]`. 네트워크 응답 파일과 스크립트는 `/tmp/studyclub-search-r1/`에 있으며 제품 소스에 포함하지 않는다.

이 확인은 공개 endpoint·현재 DTO/Mapper의 응답 호환성을 보여 준다. 앱의 Alamofire 경로, 필터·페이지·상세 이동 및 화면·IME 검증을 대신하지 않는다. 검색은 InProgress/OFF다. XCTest와 Simulator 결과는 사용권 인계 뒤 별도로 기록한다.
