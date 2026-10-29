# 로그인 View — SC-50

로그인 전용 UIKit 화면과 표시 상태를 구현했다. 가입 화면과 인증 실행은 포함하지 않는다. [작업 50](https://app.notion.com/p/benkang/6daefa197f2b410aa0009043019b60bd)과 [Google 로그인 이슈](https://app.notion.com/p/benkang/3d283feabad380e68548d0d557eefbf7)에 해당한다.

- `LoginViewModel.State`: `idle`, `signingIn`, `cancelled`, `failure`, `unavailable`. 생성자 또는 `update(state:)`로 하드코딩 상태를 전달한다. 진행 중에는 중복 시작을 막고 취소를 제공한다. 취소·실패에서는 Google 버튼으로 다시 시작한다. 설정 미완료에서는 버튼을 비활성화한다.
- `LoginViewController`는 공식 `GIDSignInButton` wide 스타일과 밝기별 색상을 유지한다. SDK 10.0.0의 wide 버튼은 그룹의 안쪽 폭을 채운다. SDK의 최소 폭과 48pt 고정 높이를 유지하며 그룹의 좌우 여백은 16pt, 위아래 여백은 8pt다. 버튼 영역 높이는 SDK 버튼 높이에 2pt를 더한다. 상단 제목·소개 아래에 로그인 수단 그룹을 둔다. 그룹은 가입 B안의 surface·테두리·16pt 모서리를 재사용하며, 공식 버튼 아래에 상태 설명과 필요한 취소 동작을 배치한다. 상태가 달라져도 버튼 위치를 유지한다. 스크롤, safe area, 20pt 좌우 여백, 24pt 위아래 여백과 최대 560pt 본문 폭을 유지한다. 디자인 플래그 ON은 크림·흰색·녹색, OFF는 시스템 light/dark 색상을 따른다.
- 생성자의 `onGoogleSignIn`은 표시 상태를 진행으로 바꾼 뒤 현재 화면을 전달한다. `onCancelSignIn`은 취소 표시 후 호출한다. `onClose`는 모든 상태에서 호출하며, 소유자가 인증 작업 무효화와 화면 닫기를 맡는다. 화면은 자체적으로 SDK 인증·네트워크·저장·화면 전환을 수행하지 않는다.
- Task 52는 ViewModel을 보관하고 실제 결과를 표시 상태로 변환한다. 성공과 신규 회원 분기, 늦은 결과 차단, 실제 취소, 기능 OFF에 따른 종료는 연결 작업의 책임이다. 실패 상세 데이터나 Domain 인증 타입을 이 View로 넘기지 않는다.
- 설정 계정이 플래그 ON에서 로그인을 선택하면 이 화면을 전체 화면 모달로 연다. 화면은 여전히 SDK 인증·네트워크·저장을 직접 수행하지 않고, 결과 표시는 `SettingAccountViewModel`이 `update(state:)`로 반영한다. `auth.google-login`은 InProgress/OFF다.

GoogleSignIn-iOS는 SC95와 동일한 10.0.0 및 PBX 식별자를 사용한다. 패키지 연결은 공식 버튼 표시용이며 OAuth 설정이 완료됐다는 뜻이 아니다. Debug·Release 빌드와 기존 단위 테스트, 설치된 임시 검증 화면의 다섯 상태·320pt 폭·긴 한국어·플래그 ON/OFF 및 synthetic 콜백을 별도 증거로 확인한다. 이 확인은 실제 Google 인증·API·물리 기기 또는 독립 최종 검증을 뜻하지 않는다. SC52 연결과 독립 후보 검토는 남아 있다. 임시 화면 검증 코드는 제품 소스에 포함하지 않는다.

## 구글·애플 실연동 (2026-10-28)

- 번들 ID 는 `life.studyclub`(팀 NR984AHM5Z). 구글 iOS OAuth 클라이언트가 이 번들에 묶여 있고, 클라이언트 ID 세 개는 공개값이라 `Config.xcconfig` 에 둔다. `GID_SERVER_CLIENT_ID` 는 서버가 교환에 쓰는 웹 클라이언트다.
- 구글은 `redirectUri` 를 **빈 문자열**로 보낸다. SDK 의 serverAuthCode 는 콜백 없이 발급되고, 생략하면 서버가 웹 콜백을 넣어 교환이 실패한다.
- 애플은 `AppleSignInProvider`(AuthenticationServices)가 authorization code 와 첫 인가에만 오는 이름을 받아 `provider: "apple"` 로 보낸다. 서버 계약은 studyclub-engineering `specs/auth-apple-login`.
- 로그인 화면의 두 버튼은 같은 틀(50pt 높이·`Radius.control`·17pt semibold·아이콘 왼쪽)로 직접 그린다. SDK·시스템 버튼은 모양이 서로 달라 쓰지 않는다. 브랜드 규칙은 지킨다: 구글은 SDK 의 공식 "G"(`GoogleLogo` 에셋), 흰 바탕·회색 테두리, 애플은 `apple.logo`·검정 바탕. 문구는 「Google로 계속하기」「Apple로 계속하기」. 색은 시스템 다크가 아니라 버튼 뒤 surface 밝기를 따른다(디자인 시스템은 다크에서도 밝은 surface). 상태 다섯 가지와 「다른 방법으로 가입된 이메일」(409)은 두 버튼이 같이 쓴다.
- 아래 SC-50 의 `GIDSignInButton` 설명은 이 변경으로 대체됐다.
- API 호스트는 `API_HOST`(Config.xcconfig → Info.plist `StudyClubAPIHost`). stage 로 확인하려면 `Config.local.xcconfig` 에 `API_HOST = api-stage.studyclub-plusplus.com`.
- 시뮬레이터에서 애플 로그인은 시뮬레이터 설정 앱에 Apple 계정이 로그인돼 있어야 한다.
