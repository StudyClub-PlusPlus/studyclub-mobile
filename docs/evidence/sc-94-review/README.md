# SC-94 적대적 코드 리뷰 · 2026-10-09

사용자가 작업 번호를 SC-94로 확인했다. 브랜치는 main b95f127 기반 `junsu/sc-94`, 제목 접두사는 `[sc-94]`다. [기존 MyPage 참고 이슈](https://app.notion.com/p/benkang/3d283feabad38098a5c9fb0d420ac198)는 유지했고 외부 이슈 상태·담당을 변경하지 않았다. 리뷰 당시 변경은 미커밋이었다. 이후 사용자의 요청에 따라 이 검증 후보를 SC-94 PR로 제출한다.

## 검토 방식

최신 AGENTS.md와 architecture/conventions/testing/state 문서를 기준으로 실제 요청 경계, 세션 상태, 취소 경쟁, UIKit 제약, 테스트의 거짓 통과 가능성을 직접 검토했다. 별도 독립 리뷰어가 검증한 결과는 아니다.

## 발견 및 수정

| 우선순위 | 문제 | 수정 및 확인 |
| --- | --- | --- |
| P2 | Real repository는 기능 OFF를 확인하지 않아 ViewModel 밖에서 사용하면 요청이 실행될 수 있었다. | repository가 immutable flag를 캡처하고 토큰 검사·요청 전에 차단. OFF의 오류가 unauthorized가 아닌 unavailable인지 직접 검사. |
| P2 | 취소 오류가 일반 unavailable로 바뀌고 취소된 401이 세션을 지울 수 있었다. | 요청 전·성공·catch에서 cancellation 확인. Swift/Alamofire 취소를 보존하고 취소 뒤에는 세션 변경을 하지 않음. 늦은 응답과 오류 분류 회귀 테스트. |
| P2 | 숨기는 arrangedSubview 버튼에 required 최소 높이가 있어 UIStackView의 숨김 높이 0과 충돌할 수 있었다. | 두 버튼의 최소 높이 우선순위를 999로 낮춤. 로딩·회원·만료의 최종 화면 다시 확인. |
| P3 | 실패 문구는 다시 방문하면 조회할 것처럼 안내하지만 root-owned 모델은 다시 요청하지 않았다. | 실제 가능한 이전 화면의 스터디 탐색을 안내하도록 수정. |
| 규칙 | repository가 직접 HTTP를 수행하고 DTO 파일에 mapper가 섞였으며 여러 repository가 한 파일에 있었다. | 내부 생성 AccountAPIClient, Mappers/AccountMapper, Live/MockAccountRepository 파일로 분리. 추가 DI·Client 주입은 없음. |
| 규칙 | SC-94 코드의 설명 주석, 축약된 한 줄 블록과 익명 인자, Shell 명명이 남아 있었다. | 추가 코드 주석 제거, 블록 확장, 명시적 변수명, MyStudiesViewController로 정리. 기존 main의 DTO/API/UIKit 표준 타입명과 무관한 기존 코드는 유지. |

현재 범위에서 남아 있는 수정 필수 결함은 발견하지 못했다. 이는 실제 로그인·API 연결 검증을 대신하지 않는다.

## 최종 후보 검증

저장소 루트에서 실행:

```sh
xcodebuild test -project ios/studyclub.xcodeproj -scheme studyclub -destination 'platform=iOS Simulator,id=A893B811-CF88-4164-BE91-22911A424235' -derivedDataPath /tmp/studyclub-mypage-main-build -resultBundlePath /tmp/sc94-review-tests.xcresult -parallel-testing-enabled NO
xcodebuild build -project ios/studyclub.xcodeproj -scheme studyclub -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/studyclub-mypage-main-build
```

- Xcode 26.2 / iPhone 17 Pro iOS 26.2: 단위 테스트 **58개 통과, 실패 0**.
- 일반 Release 빌드 성공. 로그 `/tmp/sc94-review-tests.log`, `/tmp/sc94-release.log`.
- `git diff --check` 통과.
- UI 테스트 타깃·영구 QA scenario·설정용 테스트 override를 추가하지 않았다.
- iPhone 17 Pro iOS 26.0의 실제 앱에서 프로필 진입 → 비로그인 → 데모 계정 → 로그아웃 → 스터디 루트 복귀를 직접 조작해 확인했다. `guest.png`, `content.png`, `after-logout.png`.
- 최종 소스 복사본 `/tmp/sc94-controlled`에만 임시 Domain repository를 넣었다. 별도 bundle `studycub.studyclub.mypageqa`의 loading/failure/expired/dark 캡처는 제어된 렌더 증거다. 제품 소스에 QA 코드를 넣지 않았다. `controlled-*.png`.
- 오류 문구 줄바꿈, 버튼 숨김, 계정 정보 배타성, 카드 너비·안전 영역을 재검토했다. 이전 iPad·로그인 화면 캡처는 최초 후보 기록에 남아 있으며 이번 후보의 추가 검증으로 집계하지 않는다.

## 범위 밖 의존성

모바일 Google 인증 실행·공유 로그인 세션이 아직 구현되지 않아 실제 사용자 토큰으로 GET /auth/me 응답·디코딩을 검증하지 못했다. Real/Release는 nil 세션으로 시작하며 Mock fallback이 없다. 인증 연결은 해당 담당 작업 이후에 진행한다. 프로필 수정 계약·원격 사진·참여 이력은 완료로 표시하지 않는다. 구글 로그인 구현은 SC-94에 추가하지 않았다.
