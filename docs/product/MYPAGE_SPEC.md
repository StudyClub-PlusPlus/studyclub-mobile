# MyPage 구현 범위 · SC-94

[상위 이슈 #94](https://app.notion.com/p/benkang/3d283feabad38098a5c9fb0d420ac198)의 2026-09-18 합의를 기준으로 한다. 이슈 담당·상태는 변경하지 않았다. 사용자가 작업 번호를 SC-94로 확인했다. 작업 브랜치는 `junsu/sc-94`이며 PR 대상은 `main`이다.

## 현재 동작

- `account.mypage`는 InProgress, 기본 OFF. OFF는 기존 스터디/설정 탭을 유지하고 계정 조회·데모 진입을 실행하지 않는다.
- Debug에서 스터디 탭을 길게 눌러 Development Settings → “MyPage · 앱 재실행”을 켜고 재실행한다. 탭 재구성 시에도 새 플래그 값을 읽는다.
- ON은 스터디/내 스터디 두 탭이다. 두 루트의 “프로필” 버튼에서 MyPage를 연다. 상단 우측 배치는 현재 구현 선택이며 최종 진입 위치 합의는 TBD다.
- 기본은 비로그인. Mock 모드의 “데모 계정으로 둘러보기”만 샘플 닉네임·이메일을 표시하며 데모 안내를 함께 보여 준다. 실제 인증으로 취급하지 않는다.
- 로그인 버튼은 기존 SC-50 LoginViewController의 unavailable 상태를 재사용한다. OAuth·세션 연결은 SC-52 후속이며 Google 버튼은 비활성이다. 닫으면 MyPage로 돌아온다.
- 로그아웃은 repository의 메모리 세션과 화면 정보를 지우고 모든 탭의 탐색 스택을 루트로 되돌린 후 스터디 탭을 선택한다. 다시 프로필에 들어가면 비로그인 안내를 표시한다.
- 401은 세션을 지우고 재로그인 안내를 표시한다. 일반 조회 실패는 계정 정보를 표시하지 않고 로그아웃을 제공한다. 재시도·자동 갱신은 없다.
- 내 스터디는 비로그인 안내와 로그인 버튼, 로그인 후 준비 중 안내만 제공한다. 참여 목록·참여 이력·일정 구현은 #118/#119다.
- 프로필 이미지는 기존 원격 이미지 로더가 없어 시스템 심볼로 표시한다. 편집·북마크·회원 탈퇴는 추가하지 않는다.

## API 확인과 미연결 범위

engineering의 AuthController/AuthDtos 코드에 `GET /auth/me`가 있다. Bearer 토큰을 사용하며 응답은 래퍼 없는 AccountView다. id/email/nullable nickname/picture를 Data에서 Domain으로 매핑한다. picture는 HTTPS URL만 보관하며 아직 화면에서 내려받지 않는다.

`RepositoryFactory.makeLiveAccountRepository(accessToken:refreshToken:)`와 LiveAccountRepository에 조회 요청 코드를 준비했다. base URL은 기존 production host 루트이며 `/auth/me`를 붙인다. Debug는 저장된 Mock/Real 모드, Release는 항상 Real을 사용한다. 플래그는 repository 종류를 바꾸지 않는다.

현재 로그인 세션 공급자가 없어 Real/Release는 nil 토큰으로 생성되고 인증 요청을 보내지 않는다. 실제 배포 서버의 인증된 응답·DTO 디코딩은 미검증이다. 이 변경을 실제 API 연동 완료로 보지 않는다. OAuth 결과 연결·영속 토큰 저장·갱신·앱 재실행 세션 복원은 후속 범위다. 현재 토큰은 메모리에만 있으며 로그아웃 시 access/refresh 값을 모두 비운다.

engineering에는 `PATCH /api/me` 프로필 수정 스펙만 있고 확인한 체크아웃에 구현은 없다. 모바일 프로필 수정 필드·이미지 정책·수정 API 계약은 TBD다.

## 구조와 상태

UIKit/Auto Layout + MVVM + Repository를 유지한다. Domain에 Account와 AccountRepository, Data에 DTO/매퍼와 구현체를 둔다. MainTabBarController가 한 MyPageViewModel을 소유해 두 탭의 상태를 공유한다. ViewController는 repository를 전달하지 않는다.

뷰모델은 private CurrentValueSubject와 read-only publisher를 사용한다. 초기 세션 조회와 명시적인 Mock 진입만 요청을 시작한다. 하나의 Task를 유지하며 로그아웃 시 취소한다. 취소된 요청의 성공·실패는 화면에 적용하지 않는다. 로딩/회원/비로그인/만료/실패는 서로 배타적이다.

## 검증

[최신 리뷰·검증 기록과 캡처](../evidence/sc-94-review/README.md)를 참고한다. 임시 QA 호스트의 제어된 화면 캡처는 실제 API나 인증 전환의 증거가 아니다. 영구 UI 테스트 타깃·시나리오 인자·설정 테스트용 override는 추가하지 않았다.

Repository도 플래그 OFF를 요청 전에 차단한다. AccountAPIClient는 요청·디코딩, AccountDTO의 toDomain은 매핑, LiveAccountRepository는 오류 분류·세션 파기를 맡는다. 취소 오류는 일반 실패로 바꾸지 않으며 취소된 요청은 세션을 변경하지 않는다.
