# 내 스터디 LIST 연결 · SC68

이 변경은 인증 요청·목록 Repository·ViewModel을 실제 탭 root에 연결한다. 상위 탭은 `스터디 / 내 스터디`이며 두 탭의 프로필 버튼은 별도 UINavigationController를 fullScreen으로 연다. 프로필에서 시작한 로그인 성공·취소는 프로필에 남고, 내 스터디 로그인 게이트의 성공·안전한 취소는 원래 목록으로 돌아간다. 두 탭의 선택과 기존 navigation stack은 유지한다. 이 문서는 live OAuth·배포 QA 증거가 아니다.

기존 구현은 `MyStudiesRouter`, `MyStudiesAPIClient`, `DefaultMyStudiesRepository`를 별도로 두었다. SC67의 작업 설명은 API 계약과 client 구현을 좁게 제한했고 PR #14도 `RepositoryFactory`, Auth, View, FeatureFlag 같은 공통 코드를 바꾸지 않았다고 기록했다. SC68에서 기존 Auth actor를 연결하면서 별도 Study Repository도 추가했다. 이 분할은 작업 간 충돌을 줄였지만, 공유 `StudyRouter`와 `Repository`를 재사용하라는 기존 아키텍처 규칙과 충돌했다. 이를 새 규칙으로 정당화할 근거는 없으므로 현재 구조는 통합한다.

현재는 `StudyRouter`가 기존 `/api/` base URL, 기본 헤더와 `GET /api/me/studies` 경로를 함께 만든다. `StudyAPIClient`가 요청·디코딩을 맡고 `Repository`가 DTO→Domain 변환, 오류 분류와 플래그 경계를 맡는다. `RepositoryFactory`는 기존 `RepositoryProtocol` 구현 하나를 root에서 계정 모델과 공유한다. `DefaultAuthRepository.withAuthorization`은 Data 내부 호출점이며 기존 epoch·완료 credential·1회 refresh·저장 보상 규칙을 재사용한다. 최종 인증 거부에 따른 credential 삭제 전에도 epoch를 무효화하므로 같은 세션의 늦은 refresh가 credential을 다시 저장하지 못한다. 삭제 실패는 실패로 유지하며 기존 저장값을 보존한다. `AuthRepository`는 credentials와 세션 수명주기만 소유한다.

`MemberAreaViewModel`의 앱용 initializer가 `RepositoryFactory.makeMemberRepositories()`를 한 번 호출한다. 이 root 범위의 같은 Auth actor가 설정·프로필·로그인과 내 스터디 요청을 담당한다. 이 모델은 구체적인 두 ViewModel의 구성과 상태 전달만 맡는다. 전역 세션이나 범용 DI 계층은 없다. ViewController는 Repository를 받지 않는다.

목록 ViewModel은 Domain Member를 주입받아 로그인 상태를 확인한다. 비회원과 플래그 OFF는 Repository를 호출하지 않는다. 회원이면 초기 1회 호출하며 한 Task로 refresh·취소를 관리한다. 로그아웃/미확인 세션은 표시 목록과 선택을 즉시 지운다. 취소된 응답의 성공·실패·완료는 새 요청을 바꾸지 않는다. refresh 실패는 기존 콘텐츠를 유지하고 성공한 빈 응답은 지운다. 서버 403은 가입 정보 확인 안내와 세션 재확인 요청으로 구분한다. 페이지네이션은 없다.

목록의 인증 실패와 미확인 세션의 재시도는 같은 계정 ViewModel에 세션 재확인을 요청한다. 로그아웃 등 계정 작업 중에는 그 작업을 취소하지 않고 완료 뒤 한 번 재확인한다. 확인 중에는 목록을 지우고 loading으로 표시하며, guest·회원·연결 실패 결과를 목록에 전달한다. repository mode 변경은 기존 목록을 중단하고 계정 정리가 성공한 뒤 새 root를 구성한다. 정리가 실패하면 기존 root를 유지한다.

선택은 diffable identifier를 검증한 뒤 기존 공개 Detail 화면에 같은 Study.ID를 넘긴다. 인증 전용 상세 API·캘린더는 이 범위에 없다.

`study.my-studies`는 생성 시 읽는 InProgress 기본 OFF 값이다. 기존 `Repository`도 요청 전에 이를 확인한다. Debug `MockRepository`는 순수 Domain 샘플만 반환하며 화면의 회원 게이트는 유지한다. `RepositoryFactory`는 플래그로 Mock/Real을 고르지 않고 Release는 항상 Real이다. 로컬 테스트의 Member 주입은 실제 토큰·인증 우회를 뜻하지 않는다.

검증 대상은 `MemberAuthorizationTests`(최종 거부→늦은 refresh 포함 11개), `MyStudiesListIntegrationTests`(세션·취소·refresh·403 경계 6개), `MemberAreaViewModelTests`(guest·회원/로그아웃·인증 OFF·작업 중 재확인·거부 뒤 요청 상한·가입 안내·실패한 정리 재시도 7개)다. 실제 실행 결과와 root/화면 QA는 별도 정확 후보에 연결한다. OAuth 값·서버 코드 교환·법적 승인·배포 QA가 없으므로 Ready는 별도 Draft 게이트로 남는다.

목록 권한 거부 뒤 자동 계정 재확인은 한 번만 한다. 계정이 같은 회원으로 확인돼도 이미 거부된 목록을 자동으로 다시 요청하지 않고 failure를 유지한다. 사용자가 당겨서 재시도하면 세션 확인과 다음 목록 요청을 시작할 수 있다. 계정이 guest로 확인되면 가입 정보 확인 문구를 유지한다. 목록에서 시작한 세션 재확인도 실패한 미완료 가입 정리를 먼저 재시도하며, 정리가 또 실패하면 restore를 호출하지 않는다.
