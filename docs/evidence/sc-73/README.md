# SC73 로컬 인증 후보 근거

2026-10-23, base `cf57fab89072bc142fda4e7c0bfaa0726fd77eee`, branch `junsu/sc-73`. iOS source tree `bc9b8f38a7ab0e982cbb617772f3e99b871a1be9`. 이 소스로 아래 빌드·테스트·변경 화면을 확인했다. 문서와 캡처 추가는 iOS tree를 바꾸지 않는다.

- [작업73](https://app.notion.com/p/benkang/8768d232c6b145ba9d194f7c4050e581), [상위95](https://app.notion.com/p/benkang/3d283feabad380e68548d0d557eefbf7), [외부 설정 이슈172](https://app.notion.com/p/benkang/c833f839ac2d4a8fb011e22f2dce6164).
- Xcode 27.0 (27A266a), iPhone 17 Pro / iOS 26.5, UDID `2D7F14A8-E897-41DE-8CBC-2D31B1E704D7`, bundle `studycub.studyclub`. 기존 기기를 재사용했으며 복제·삭제하지 않았다.
- Debug Mock, guest seed, auth/MyPage/MyStudies ON override. 기본값은 모두 InProgress/OFF다. OAuth client ID는 빈 기본값이다.
- Debug 실행 파일 SHA-256 `4ed13e5b3542ac66f8f45fe617a022543f401f1fd88e422509ae921099770451`.
- Release 실행 파일 SHA-256 `28309474c36ce8e3176ed6da87af4f0a7d7b520c7eaf84b3e5deb99d4e0ae631`.

## 빌드와 단위 테스트

outer monorepo에서 같은 DerivedData와 named device를 사용해 순서대로 실행했다.

```sh
xcodebuild -project ios/studyclub.xcodeproj -scheme studyclub -configuration Debug -destination 'platform=iOS Simulator,id=2D7F14A8-E897-41DE-8CBC-2D31B1E704D7' -derivedDataPath /tmp/studyclub-auth-local-derived -parallel-testing-enabled NO test
xcodebuild -project ios/studyclub.xcodeproj -scheme studyclub -configuration Release -destination 'platform=iOS Simulator,id=2D7F14A8-E897-41DE-8CBC-2D31B1E704D7' -derivedDataPath /tmp/studyclub-auth-local-derived -parallel-testing-enabled NO build
```

Debug 194개 테스트가 실패 없이 통과했다(20:43:47 KST). Release build도 성공했다. 새 root 테스트 두 개는 실제 MockAuthRepository를 통해 필수 동의·가입·회원 목록·로그아웃, 가입 중단 후 동의 초기화를 확인한다. 기존 테스트는 Real 미승인 약관 차단, 설정 미완료, 취소, 불확실한 가입 결과, 실패한 정리와 로그아웃 재시도를 확인한다. 이 테스트는 실제 Google OAuth·배포 인증을 실행하지 않는다.

원시 로그: `/tmp/studyclub-sc73/debug-test.log`, `/tmp/studyclub-sc73/release-build.log`. 보관한 요약은 [test-summary.txt](test-summary.txt)에 있다.

## 설치 앱의 native 조작 · iPhone 17e

parent가 기존 iPhone 17e / iOS 26.5 (`8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1`)를 선택하고 같은 Debug 앱을 설치했다. 설치 실행 파일의 SHA-256이 위 Debug 제품과 일치한다. 21:09~21:15 KST에 CUA DeviceHub native 창에서 다음 경로를 확인했다. LLDB나 제품 소스 변경을 사용하지 않았다.

| 화면 | 관측 |
|---|---|
| [Mock 로그인](native-mock-login.png) | 개발 설정에서 Mock·auth ON을 확인하고 설정 로그인 행과 Google 버튼을 눌러 가입으로 이동했다. |
| [Mock 가입](native-mock-signup.png) | 테스트 안내가 표시되고 필수·선택 동의 4개는 OFF, 가입 버튼은 비활성으로 시작했다. |
| [이용약관](native-terms.png)·[개인정보 처리방침](native-privacy.png) | 각 원문을 열고 back으로 폼에 복귀했다. 원문 개정일은 2026-09-10이다. 현재본 승인 여부를 뜻하지 않는다. |
| [제출 가능](native-consent-ready.png) | 필수 3개 ON에서 버튼이 활성화되고 선택 마케팅 동의는 OFF다. |
| 가입 중단·재시작 | 닫기→그만두기로 설정에 돌아갔다. 다시 가입하면 동의 4개가 OFF이고 제출 불가였다. |
| 가입·[로그아웃](native-guest-after-logout.png) | 닉네임을 `로컬회원`으로 수정하고 필수 동의만 입력해 완료했다. 설정 AX에 `로컬회원, 로그인됨`이 표시됐다. 로그아웃 확인 뒤 guest로 복귀했다. |
| [Real 미설정](native-real-unconfigured.png) | 개발 설정에서 Real로 바꿨다. 재구성된 로그인에는 Mock 안내가 없고, Google 버튼은 설정 미완료 안내와 함께 비활성화됐다. 인증 제공자 화면은 열리지 않았다. 닫기는 guest 설정으로 돌아왔다. |

닉네임은 native 텍스트 필드의 AX set-value로 수정했다. 버튼·동의·문서·중단·완료·로그아웃·모드 전환은 native 클릭으로 확인했고 하단 폼은 드래그로 스크롤했다. 소프트웨어 키보드와 물리 키 입력은 검증하지 않았다. native 캡처는 1170×2532 원본이며 [SHA-256 목록](capture-sha256.txt)을 남겼다. 확인 뒤 17e를 Debug Real·auth ON·나머지 회원 플래그 OFF·설정 guest 상태로 parent에 반환했다.

## 이전 제어 화면과 한계

17 Pro의 [로그인](mock-login.png)·[가입](mock-signup.png)은 LLDB로 UserDefaults와 기존 UIControl 콜백을 실행한 제어 렌더다. 1206×2622 원본이며 임시 제품 소스나 별도 화면 호스트를 추가하지 않았다. 같은 기기의 다른 앱 사용이 확인돼 기기를 보존하고 lease를 반환했다. 실제 터치 근거는 위 17e 결과다. 사용한 LLDB·debugserver와 task-owned serve-sim helper는 종료했다.

Release는 빌드와 소스의 강제 Real 구성·Mock 예외 차단을 확인했다. 이번 후보의 Release 설치 UI, 소프트웨어 키보드, 실제 OAuth·배포 인증은 미확인이다. 실패·불확실 결과·취소의 비동기 경계는 deterministic 단위 테스트 근거이며 강제 실패 UI를 새로 만들지 않았다. stable DerivedData 약 820MB는 후속 검증을 위해 보존했고 Simulator·XCTest 데이터는 삭제하지 않았다.

## 외부 미확인 사항

실제 client ID·URL scheme·서버 교환, 기존/신규 Google 계정, 배포 세션 복원과 로그아웃, 약관 현재본·법적 승인은 이슈172에 남는다. `AuthDocuments.allowsConsentAndSubmit`은 false다. SC53/SC69 Ready와 PR16은 변경하지 않았다. 독립 리뷰·최종 수락·병합은 리드가 맡는다.
