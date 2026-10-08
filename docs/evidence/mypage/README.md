# MyPage 최초 후보 검증 · 2026-10-09

아래는 적대적 리뷰 이전 후보의 기록이다. 사용자 확인 작업 번호는 SC-94, 현재 브랜치는 `junsu/sc-94`다. [최신 수정·검증 기록](../sc-94-review/README.md)을 기준으로 확인한다.

- 기준: `main`을 `git pull --ff-only origin main`으로 b95f127까지 갱신한 뒤 `codex/mypage`에서 작업. 기존 boa/sc-93 변경은 `codex-mypage-before-main-update-20261009` stash에 보관했다.
- 현재 후보: 이 디렉터리와 함께 있는 미커밋 변경. 커밋·푸시·PR 없음. Notion 상태·담당 변경 없음. 실제 작업 DB ID/발행용 브랜치명은 미확인.
- UIKit + MVVM + Repository를 유지하고 SC-50 로그인 View를 재사용한다. account.mypage는 InProgress/default OFF.

## 빌드·단위 테스트

저장소 루트에서 실행:

```sh
xcodebuild test -project ios/studyclub.xcodeproj -scheme studyclub -destination 'platform=iOS Simulator,id=A893B811-CF88-4164-BE91-22911A424235' -derivedDataPath /tmp/studyclub-mypage-main-build -resultBundlePath /tmp/studyclub-mypage-final-tests.xcresult -parallel-testing-enabled NO
xcodebuild build -project ios/studyclub.xcodeproj -scheme studyclub -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/studyclub-mypage-main-build
```

Xcode 26.2. iPhone 17 Pro / iOS 26.2 단위 테스트 51개 통과, 실패 0. 일반 Release 빌드 성공. 마지막 레이아웃 수정 후 결과다. 로그는 `/tmp/studyclub-mypage-final.log`, `/tmp/studyclub-mypage-release-final.log`, 결과 번들은 위 경로다. `git diff --check` 통과.

## 실제 앱 직접 조작

iPhone 17 Pro / iOS 26.0, bundle `studycub.studyclub`, Debug Mock, 디자인 플래그 OFF. 기존 Simulator 데이터는 초기화하지 않았다.

- OFF에서 기존 스터디/설정과 프로필 버튼 부재 확인.
- 실제 Development Settings 스위치를 켜고 앱 재실행, 스터디/내 스터디와 프로필 버튼 확인: `main-entry.png`.
- 프로필 → 비로그인 안내: `guest.png`.
- 로그인 → 기존 로그인 View unavailable, 닫기 → MyPage 복귀: `login-unavailable.png`.
- 데모 계정 → 닉네임/이메일/데모 안내 확인: `content.png`.
- 로그아웃 → 스터디 루트 복귀 → 프로필 재진입에서 이름 제거·비로그인 안내 확인.
- 내 스터디 탭 선택만으로 로그인 화면이 자동 열리지 않음. 로그인 버튼 → MyPage, 데모 상태 공유 및 뒤로 가기 확인: `my-studies-guest.png`, `my-studies-placeholder.png`.

## 제어된 렌더 (실제 API 증거 아님)

최종 소스를 `/tmp/studyclub-mypage-controlled`로 복사하고 SceneDelegate에만 Domain 테스트 repository를 주입했다. 별도 bundle `studycub.studyclub.mypageqa`이며 QA 코드·launch 인자는 저장소에 포함하지 않았다. 실제 요청이나 OAuth를 실행하지 않았다.

- `controlled-loading.png`: 로딩, 계정 내용과 버튼 숨김.
- `controlled-failure.png`: 조회 실패와 로그아웃, 계정 정보 숨김.
- `controlled-expired.png`: 만료 안내와 로그인 유도.
- `controlled-content.png`: 디자인 OFF의 시스템 다크 모드 계정 카드.
- `controlled-ipad.png`: iPad Pro 11-inch (M5) / iOS 26.0, 최대 560pt 읽기 폭과 안전 영역 확인.

한글 줄바꿈, 카드 너비, 상태 배타성, 안전 영역을 시각적으로 검토했다. 최초 카드 너비가 내용에 따라 달라지는 문제를 수정하고 다시 캡처했다.

## 남은 외부 연결

GET /auth/me 요청 코드는 준비했으나 실제 사용자 토큰·서버 응답은 미검증이다. SC-52 인증/세션 연결, 영속 저장·갱신, 원격 프로필 사진, 프로필 수정 API는 미완료. 참여 이력·일정은 #118/#119 범위다. 전체 인증 기능 완료 또는 배포 QA 완료로 해석하지 않는다.
