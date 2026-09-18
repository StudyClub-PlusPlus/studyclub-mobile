# 스터디 목록·검색 분리 및 연결 계획

상태: 기획 의도 및 병행 개발 계획을 기록한 초안이며, 기능의 구현이나 배포 완료를 뜻하지 않는다.

## 1. 두 피처의 책임 분리

| 피처 | 담당 영역 및 책임 | 아키텍처 규칙 |
|---|---|---|
| 스터디 목록 | 모집 중 스터디 기본 표시(`?status=OPEN`), 기본 탐색 데이터·상태(loading/content/empty/failure), 스크롤 위치 및 기본 필터 상태 보존, 검색 진입점 제공. status는 코호트 모집 상태(DRAFT/OPEN/CLOSED) | UIKit MVVM + Repository 준수, DTO는 Data 내부에 격리 |
| 스터디 검색 | 전체 공개 스터디 대상(필터 기본값 '전체', 즉 status·category 파라미터 미전송), 독립 결과 VC 및 ViewModel, query 상태 및 디바운스 자동 갱신, 독자적 검색 필터 상태 관리(기본 탐색 필터와 분리·상호 영향 없음), 검색 결과 상태(loading/content/empty/failure), 항목 선택 시 Study.ID 전달. 카테고리 필터(`?category=<StudyCategory>`) BE 지원 확인. 모집 상태 필터(`?status=OPEN` 등) BE 지원 확인. 필터 범위는 모집 상태 + 카테고리. 선택 UI·레이블·배치만 미결정 | UIKit MVVM + Repository 준수, DTO는 Data 내부에 격리 |

## 2. 피처 간 연결 계약 초안

- **데이터 격리**: 검색 결과 데이터로 호스트(기본 목록)의 Diffable DataSource snapshot이나 items를 직접 덮어쓰지 않는다.
- **필터 상태 격리**: 검색의 필터 상태는 독자적으로 동작하며, 기본 탐색 목록의 필터 상태를 변경하거나 상속받지 않는다.
- **상세 이동 연결 및 Study.ID 직접 전달**: 검색 결과에서 특정 스터디 선택 시 `Study.ID`를 호스트 VC에 전달하여 Detail 화면으로 이동한다. 마감된 스터디 등 기본 탐색 목록(모집 중)에 존재하지 않는 항목도 `Study.ID`로 상세를 열 수 있어야 하며, 기본 탐색 ViewModel의 내부 목록 조회를 요구하지 않는다 (구체적인 callback/delegate 이름은 상세 설계 시 확정).
- **상태 보존 검증**: 검색 모드 종료(Cancel) 시 원래 탐색 목록의 필터와 스크롤 위치가 유지되는지 실제로 확인한다. `UISearchController`가 상태를 무조건 정확히 복원해 준다고 전제하지 않는다.
- **비동기 격리 및 늦은 응답 방지**: 빠른 입력 시 이전 검색의 늦은 응답(late earlier response)이 최신 결과를 덮어쓰지 못하도록 보장한다. 검색 종료 시 진행 중인(pending/in-flight) 검색 작업이 기본 탐색 목록의 상태를 변경하지 못하도록 요청 수명주기를 격리한다.

## 3. 두 피처 이슈 초안

- **스터디 목록 이슈 #92 (개발 중 상태 유지)**
  - **목적**: 모집 중 스터디 목록 기본 탐색 제공 (현재 진행 중인 #92에 합의 범위를 반영)
  - **포함 범위**: 기본 목록 UI, Repository 연동, 상태 전이(loading/content/empty/failure), 스크롤 및 기본 필터 보존
  - **검증 기준**: 목록 렌더링, 로딩/빈 상태/실패 경로 처리, 스크롤 동작 단위 및 UI 테스트
  - **후속 구체화**: 탐색 필터 세부 UI 정책. 새로고침·페이지네이션의 필요 여부와 방식은 API 연동 명세에서 정하며, 이 초안에서 구현이나 제외를 확정하지 않는다.
- **스터디 검색 이슈 #96 (기존 미착수 중복 상세 초안을 검색으로 변경)**
  - **목적**: 전체 공개 스터디 대상 키워드 검색 및 결과 확인
  - **포함 범위**: 독립 UISearchController 결과 VC/ViewModel, 검색 디바운스 입력 처리, 독자적 필터(기본값 '전체', 모집 상태·카테고리 필터 BE 확인), 초기 빈 검색어는 검색창 플레이스홀더+필터만 표시(EmptyView 미표시, 전체 스터디 네트워크 요청 미발생), 유효 검색어 0건 시에만 EmptyView 표시, 검색어 삭제 시 초기 상태 복귀 및 pending/in-flight 응답 무효화, 선택한 Study.ID의 호스트 전달 (탐색 목록 부재 항목 포함)
  - **검증 기준 (Acceptance)**:
    - 초기 진입(빈 검색어) 시 EmptyView가 노출되지 않으며 전체 스터디 조회 네트워크 요청이 발생하지 않음
    - 유효한 검색어 입력 후 결과 0건 시에만 '검색 결과 없음'(EmptyView)이 로딩/실패와 구분되어 표시됨
    - 검색어 삭제 시 초기 플레이스홀더/필터 상태로 정상 복귀하며 이전 지연 응답이 무효화됨
    - 빠른 입력 시 디바운스가 동작하며 Search 버튼 제출 없이 입력 일시 멈춤 시 자동 갱신
    - 한글 입력기(IME) 조합(composition) 중/완료 상태 처리 검증
    - 이전 검색의 늦은 응답이 최신 검색 결과를 덮어쓰지 않음
    - 검색 종료 시 pending/in-flight 작업이 원래 탐색 상태를 변경하지 않음
    - 마감 스터디 등 기본 목록에 없는 결과도 Study.ID를 통해 상세 화면 정상 진입
  - **미결정 사항**: 모집 상태·카테고리 필터 UI·레이블·배치, 재진입 시 변경된 필터 유지 여부 (빈 검색어 진입 동작은 결정 완료)
  - **구현 시 조정**: 디바운스 대기 시간은 입력 반응과 요청 빈도로 조정한다. 새로고침·페이지네이션의 필요 여부와 방식은 API 연동 명세에서 구체화한다.
- **연결 검증**: 두 피처 간 연결 확인은 별도의 거대한 제3의 피처로 부풀리지 않고, 통합 시점의 작은 후속 체크 태스크로 검증한다.

## 4. 자산 재사용 및 아키텍처 원칙

- 피처 분리가 별도의 target, package, 독립 네트워크 스택 또는 중복 Repository 생성을 의미하지 않는다.
- 공통 스터디 카드 UI 표현, Domain 모델(`Study`), 기존 Repository 및 `RepositoryFactory` 자산을 재사용한다.
- 새로운 공통 추상화 계층, UseCase, Coordinator, Router 등을 임의로 도입하지 않는다.
- 백엔드 명세에 없는 임의의 API 쿼리 파라미터나 DTO 필드를 임의로 발명하지 않는다.

## 5. Feature Flag 및 병행 개발 전략

- Feature Flag와 trunk 기반 개발을 통해 스터디 목록 피처 전체 완료를 기다리지 않고 검색 개발을 병행한다.
- 검색 플래그 OFF 상태에서 검색 진입 UI 비노출 및 불필요한 검색 네트워크 요청 억제를 확인한다 (플래그 명칭 미정).

## 6. 공통 참고자료 (원본 및 기준본)

- [FE 디자인 시스템 원본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/develop/frontend/packages/design/docs/design-system.md) · [작업 기준본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94d6eb351dfef240d2c8ee2fd86152784fa0ae05/frontend/packages/design/docs/design-system.md)
- [FE 토큰 원본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/develop/frontend/packages/design/tokens.css) · [작업 기준본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94d6eb351dfef240d2c8ee2fd86152784fa0ae05/frontend/packages/design/tokens.css)
- [Controller 최신](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/develop/backend/api/src/main/java/com/studyclub/api/web/StudyController.java) · [기준본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94d6eb351dfef240d2c8ee2fd86152784fa0ae05/backend/api/src/main/java/com/studyclub/api/web/StudyController.java)
- [StudyListResponse 최신](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/develop/backend/api/src/main/java/com/studyclub/api/study/StudyListResponse.java) · [기준본](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94d6eb351dfef240d2c8ee2fd86152784fa0ae05/backend/api/src/main/java/com/studyclub/api/study/StudyListResponse.java)
- [FE 목록 mobile 캡처](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94d6eb351dfef240d2c8ee2fd86152784fa0ae05/frontend/apps/core-front/e2e/screen-catalog/specs/__screenshots__/study-list--default--mobile.png) — 목록/default/mobile, FE fixture (실제 운영/앱 검색 완료 증거가 아니며, 별도 검색 API 존재나 배포를 단정하지 않음)

## 7. API 연동 시 확인할 차이

- BE 기준: develop 94d6eb351dfef240d2c8ee2fd86152784fa0ae05. category/status는 Controller → Service → Repository에 구현되어 있고 관련 통합 테스트 소스가 있다. 이번 문서 작업에서 테스트 실행이나 배포 서버 호출은 하지 않았다.
- 현재 Service는 최신 기수가 없는 공개 스터디를 목록에서 제외한다. 전체 공개 스터디 검색 정책을 임의로 좁히지 않고 BE와 확인한다.
- DRAFT enum의 존재를 앱 필터 선택지 노출 승인으로 해석하지 않는다. 요일·시간대 필터는 범위에서 제외한다.

## 8. 게시한 작업 이슈

- [Notion #92 스터디 목록](https://app.notion.com/p/benkang/3d283feabad380e995dbe12fc8ea2536)
- [Notion #96 스터디 검색](https://app.notion.com/p/benkang/3d283feabad38066a5f4de97e369b382)
- [Notion 모바일 PRD](https://app.notion.com/p/benkang/3c083feabad3810c9e56d9c2e4d329b5)

2026-09-18 합의와 본문·원본 링크를 게시하고 확인했다. 목록은 개발 중, 검색은 시작 전 상태를 유지한다.
