# sc-92 모집 중 목록 API 설계

상태: 구현 전 draft. 사용자와 합의한 방향 및 독립 소스 리뷰의 보완을 기록한다. 앱 구현·Simulator 검증·최종 구현 승인을 의미하지 않는다.

- 이슈: [sc-92 스터디 리스트](https://app.notion.com/p/benkang/3d283feabad380e995dbe12fc8ea2536)
- iOS 검토 기준: `9d087d8f90edbfd64e4d3a774582069e33e74e31` (`sc-145` 기반)
- Backend 검토 기준: `94eb15f13c4b561e0d84ba77085c336365b25dad`
- 범위: 비로그인 모집 중 목록 → 안정적인 Study.ID로 독립 상세 조회. 검색은 sc-96, 스타일은 sc-116.

## 현재 문제와 API 계약

현재 Client는 `[StudyDTO]`를 읽지만 실제 응답은 `{items,total,offset,limit}`이다. 현재 목록 DTO의 string id·필수 최대 인원·옛 status 값도 서버 요약과 다르다. 이 불일치는 소스 비교 결과이며 앱에서 실패를 재현한 결과는 아니다.

모집 중 요청은 `GET /api/studies?status=RECRUITING&offset=0&limit=20`이다. 쿼리 이름은 status지만 값은 StudyPhase(RECRUITING/ONGOING/CLOSED)다. 과거 문서의 OPEN/cohort 중첩 설명을 이번 연결의 기준으로 사용하지 않는다. 항목은 flat StudySummary이며 같은 프로그램의 여러 스터디도 별도로 나온다. 정렬은 phase 순서와 studyId 내림차순이고 기본 모집 목록은 ID 내림차순이다. GET 목록·상세는 인증 없이 허용된다.

2026-10-03 익명 GET 관측: OPEN 쿼리는 HTTP 400, RECRUITING은 HTTP 200과 page 객체(items 8개,total 8,offset 0,limit 20)를 반환했다. 별도 상세 읽기도 숫자 id의 요청 일치를 확인했다. 원본 응답은 보관하지 않았다. 배포 SHA와 20개 초과 동작, 실제 앱 디코딩·목록→상세는 미확인이다.

## 사용자와 합의한 방향

- 첫 페이지 이후는 무한 스크롤로 자동 추가 로딩한다. 정상 탐색에 더 보기 버튼을 두지 않는다.
- 사용자 pull-to-refresh로 첫 페이지를 갱신한다. 상세 복귀·검색 취소 때 목록과 상대 스크롤 위치를 유지한다.
- Swift 숫자는 Int를 쓴다. Repository가 limit=20을 고정하고 Client/Router는 offset·limit 인자를 전달한다. 화면은 offset만 요청한다.
- DTO는 앱에서 쓰는 필드만 선언하며 slug는 제외한다. 필요한 표현 변환은 `init(from:)`에서 처리할 수 있고, 단순 키 변경은 CodingKeys로 충분하다.
- 기존 Repository·ViewModel에서 해결한다. 범용 페이지 관리자·요청 framework·캐시·DI·새 Feature Flag를 도입하지 않는다.

## 최소 데이터 흐름

```text
MainViewModel → Repository.fetchStudies(offset: Int)
             → StudyAPIClient.fetchStudies(offset: Int, limit: Int)
             → StudyRouter.studies(offset: Int, limit: Int)
page DTO → Mapper / Repository validation → Domain StudyPage → 카드 표시 값
선택된 Study.ID → DetailViewModel → 별도 GET /api/studies/{id}
```

Page DTO는 items와 Int total/offset/limit을 읽는다. Domain page는 studies/totalCount/offset이면 충분하며 서버 DTO가 Presentation으로 나가지 않는다. 아래는 목록에서 사용할 요약 필드다.

| 필드 | Swift 타입 | 의미 |
|---|---|---|
| studyId | Int | 양수 숫자 ID. Mapper에서 기존 String Study.ID로 변환 |
| category | StudyCategory | 기존 11개 enum 재사용, 한국어 표시는 Presentation |
| title | String | 카드 제목 |
| oneLineSummary | String | 카드 요약 |
| currentApplicants | Int | 실제로는 ACTIVE·PAUSED 참여자 수. 신청서 수가 아님 |
| capacity | Int? | null은 정원 제한 없음, 값은 1 이상 |
| phase | StudyPhase | RECRUITING/ONGOING/CLOSED, 서버 계산값 사용 |
| closingSoon | Bool | 모집 중 단계에서 마감 임박 표시용 |

slug·이미지·일정·시간대·기타 미사용 필드는 목록 DTO에 복제하지 않는다. 기존 상세 DTO의 사용 필드는 유지한다. 필수 필드 누락·잘못된 타입·unknown enum을 임의 기본값으로 숨기지 않는다. 현재 필드에는 custom `init(from:)`가 필수는 아니다.

Mapper는 양수 ID, 유효한 제목, 참여 수≥0, nullable/양수 정원을 검증한다. 정원 초과 참여 수를 일괄 거부하지 않는다. 서버는 모집 마감을 count≥capacity로 판정하며 정원 변경 등의 경우가 가능하다. phase를 앱 시간으로 재계산하거나 closingSoon을 자리 부족으로 해석하지 않는다. 기존 topics를 정리한다면 MockRepository의 Detail 샘플 생성에 필요한 내용은 별도로 보존한다.

## 페이지·갱신·실패 처리

초기 loading/content/empty/failure는 유지한다. 추가 로딩과 refresh는 기존 content를 보존한다.

- 다음 offset은 `response.offset + response.items.count`다. 중복 제거 후 표시 개수로 계산하지 않는다. offset+count<total일 때 다음 페이지 후보이며, 끝에 도달하거나 요청 중이면 추가 호출하지 않는다.
- 같은 페이지의 중복 ID는 invalidData다. 페이지 사이 같은 ID는 기존 위치를 유지하며 최신 표시 값으로 교체한다.
- total과 phase는 조회 중 바뀔 수 있으므로 단순 수 불일치나 알려진 다른 phase를 모두 오류로 만들지 않는다. Offset 방식의 중복 제거는 변동으로 인한 누락까지 보장하지 않는다.
- 첫 items=0,total=0은 empty다. count=0인데 offset<total이면 자동 진행을 멈추고 refresh를 안내한다. content가 없으면 failure, 있으면 기존 목록을 유지한다.
- 추가 페이지 일반 실패는 목록·실패 offset을 유지하고 footer에서 해당 페이지를 재시도한다. 같은 footer 노출로 실패 요청을 자동 반복하지 않는다.
- Refresh 성공 시 첫 페이지로 목록/snapshot/offset을 교체한다. 정상 빈 결과는 items/dictionary/snapshot도 비운다. 실패 시 기존 목록/cursor를 보존하고 작은 오류 표시와 함께 indicator를 종료한다.

MainViewModel에 현재 request Task 하나를 보관하는 정도로 요청을 관리한다. Refresh 전에 기존 추가 요청을 취소하고, 취소된 Task는 성공/catch/종료 정리 어느 경로에서도 표시 값·indicator·requestTask를 변경하지 않는다. Refresh 중 반복 pull과 추가 로딩은 무시한다. 이 조건이 충분하므로 별도 generation counter는 함께 두지 않는다. Alamofire transport 취소 전파는 구현 시 확인한다.

기존 publisher를 유지하되 VC의 상태 `.removeDuplicates()` 때문에 content→content 알림이 막히지 않게 한다. 표시 값 업데이트 후 알림을 보내고, 같은 ID의 변경된 카드는 명시적으로 reconfigure한다. Empty/failure에서도 기존 collection의 스크롤 surface를 유지해 native refreshControl을 사용할 수 있게 한다. 상태 표시가 당김 동작을 가로채지 않도록 한다.

## 역할과 통합 경계

- sc-92: Router/Client/DTO/Mapper/Repository, Domain 목록/page, MainViewModel/StudyCardCellViewModel 및 페이지·refresh·snapshot 연결. MainViewController 데이터 연결의 단일 writer.
- sc-116: AppTheme, 카드와 상태 화면의 스타일·레이아웃. 기존 id/category/title/summary/memberText/statusText 인터페이스를 기준으로 실제 참여 수·nullable 정원·phase/closingSoon 의미와 footer 오류 표시를 공유한다. 실제 편집 전 공통 파일 소유를 조율한다.
- sc-96: 독립 검색 VM/필터/snapshot. 검색 결과로 기본 목록을 덮어쓰지 않으며, 기본 목록에 없는 ID도 상세로 전달한다.

[선행 PR #2](https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/2)는 이 draft 준비 시 OPEN이며 sc-145와 검토 기준 iOS SHA가 일치한다. 현재 PR은 sc-145를 대상으로 문서 차이만 검토한다. 선행 PR 병합 이후 최신 main과 포함 내용을 확인하고 정렬하며 sc-145 변경을 중복 replay하지 않는다. 별도 junsu/sc-92 작업은 가져오지 않는다.

## 독립 리뷰와 이후 확인

별도 리뷰어가 위 고정 소스를 읽어 계약·DTO·합의한 방향을 검토했다. 반복 content 알림뿐 아니라 동일 ID 카드 재표시, empty 화면의 당김 접근, 0건 진행 불능·실패 복구 명세를 보완해야 한다는 의견을 이 문서에 반영했다. 이는 소스 리뷰이며 앱 QA 결과가 아니다.

이후 Mapper 변환 규칙, Repository의 추출 validation/error helper, Domain 테스트 Repository를 통한 VM 상태·늦은 응답 차단을 확인한다. DTO JSON fixture·얇은 Client/Repository 연결을 위한 주입·자동 UI 테스트·내부 설정 테스트는 추가하지 않는다. 실제 디코딩·무한 스크롤·빈 화면 당김·카드 재표시·ID 상세 이동은 이후 앱 경로에서 확인한다. Mock은 신뢰 가능한 Domain 샘플을 즉시 반환하고 기존 factory/Sendable/async 실행 문맥 정책을 유지한다.

## 고정 서버 근거

다음 링크는 검토한 git object에 고정한다.

- [StudyController](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/api/src/main/java/com/studyclub/api/web/StudyController.java): 쿼리·기본값·상세 ID
- [StudyListResponse](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/api/src/main/java/com/studyclub/api/study/StudyListResponse.java): page 및 flat 항목
- [StudyListService](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/api/src/main/java/com/studyclub/api/study/StudyListService.java) / [StudyListJpqlDao](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/api/src/main/java/com/studyclub/api/study/StudyListJpqlDao.java): 필터·정렬·페이지·count
- [Study](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/domain/src/main/java/com/studyclub/domain/study/Study.java) / [StudyParticipantRepository](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/backend/domain/src/main/java/com/studyclub/domain/participant/StudyParticipantRepository.java): 정원·단계·임박·참여 수
