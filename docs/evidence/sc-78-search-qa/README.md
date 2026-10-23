# SC78 검색 후속 네이티브 검증 · 2026-10-23–24

검색 취소 뒤 접힌 제목을 다시 그리도록 Main의 기존 offset 복원 다음에 navigation bar의 `setNeedsLayout()`과 `layoutIfNeeded()`를 호출한다. 목록 데이터·offset 정책과 검색 입력 정책은 그대로다. 타이머, offset 흔들기, 제목 모드 전환, private API를 제품에 추가하지 않았다.

[SC78](https://app.notion.com/p/benkang/009ab0ef178543e2bf74e6d3b86a805e)는 [#96](https://app.notion.com/p/benkang/3d283feabad38066a5f4de97e369b382)의 SC76 후속이다. 기준은 main `8b9e8ed917de7a6c0781cc6a5e8660e3d945ab75`, 브랜치는 `junsu/sc-78`이다. `study.search`는 InProgress·기본 OFF를 유지한다. 이 기록은 Ready 전환이나 물리 기기 전체 QA 승인이 아니다.

## 후보·환경

- Xcode27.1(27A9275), iPhone17e / iOS26.5(23F77), UDID `8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1`, bundle `studycub.studyclub`.
- 최종 ordinary Main 파일 SHA256 `bcdfbc69f3064ba9afc178a49ef6c5d5c6d97e0ebfdcfc6179ef29b5444ab5d9`.
- ordinary Release executable SHA256 `a506ae53df3ab8572d9e7c2c5b25b3ef15f67bb1c1f2c38452519433e6785d23`.
- 직렬 XCTest 직후 Debug test-host dylib SHA256 `c4e30f2128f124a04ab047f1cb2186e52fe74aef6010937165aaaa4b6440ef69`. 이후 같은 ordinary source의 명시적 Debug build가 같은 DerivedData 경로를 갱신했다. 현재 ordinary Debug build dylib SHA256은 `68bfd973674beedb5df2b77c40742157ed77f2ec6fc50cc2dd39bc568f43b711`이며, 이전 test-host 파일은 대체됐다.
- 관측 Debug r1 dylib SHA256 `9727e297562a755064822f5811021c7921983c1e87393a5e9053334761ddb417`. native-events.log의 Unix시각1792766690–1792766907 구간은 이 후보의 제목·실제 한글·실패/재시도다.
- 관측 Debug r2 dylib SHA256 `eb05107bc3f03ac798b3b9dea9cf65dd33d6ac63065cdd002d9c9f900dde2cf9`. 같은 로그의1792767033 이후는 전체 한글 키 재입력·삭제다. r1과의 차이는 SEARCH start 로그에 phase/category를 더한 것이다. 검색·제목 로직은 같다.
- r2의 [실제 임시 patch](final-probe.patch) SHA256 `681e77d3881e8472983c55e43cbaaf5c0df20e73e9e37a0e5e8637b8d9049e63`; [helper 원문](SC78Probe.swift.txt) SHA256 `51ca4f278d92fac7ad3fa7fe7e33322c73e60de3c85bd6759116273a95251ab8`. 이 두 자료는 텍스트 증거이며 앱 target에 포함하지 않는다. r1 patch는 별도로 저장하지 않았으며 위 로그 필드 차이와 바이너리를 구분한다.
- 최종 ordinary 빌드 전에 helper·Main 관측 코드·Client 관측/Session을 제거했다. StudyAPIClient는 기준 blob `d975755`와 동일하며 최종 iOS diff는 Main의 주석 포함3줄뿐이다. Release OFF/ON 및 제목 캡처는 임시 probe가 없는 동일 Release 제품이다.

## 1. 실제 한국어 키보드

기존17e의 두벌식 화면 키를 실제로 눌렀다. `ㅅ → 스 → 슽 → 스터 → 스턷 → 스터디`를 만든 뒤 공백으로 확정했고, 별도 연속6키 입력 뒤 Clear text로 삭제했다. paste/AX setValue는 이 IME 근거에 사용하지 않았다. [실제 키보드와 결과](korean-keyboard-study.png), [삭제 후 초기 화면](korean-cleared.png), [원시 이벤트](native-events.log)를 연결한다.

관측한 `textInputMode`는 ko-KR이고 기본 autocorrection은 `.no`였다. updater, UITextField.editingChanged, 다음 MainActor 실행 차례에서 **모두 marked range가 nil**이었다. 따라서 자모 결합을 UIKit marked composition으로 간주하지 않는다. nil 입력은 기존300ms 자동 검색을 따랐고 완성한 `스터디`는 HTTP200 / decoded20 / total38을 받았다. 공백 확정은 trim 후 같은 query라 새 요청을 만들지 않았고, 삭제는 초기 화면으로 돌아가 요청을 만들지 않았다. 첫 INPUT1792766818.589542 → SEARCH1792766818.906103은 약317ms다.

**한계:** 이 키보드에서 native marked!=nil 경로는 관측하지 못했다. 그 guard는 최종 후보의 deterministic XCTest가 검사한다. 매 입력 전17e 확인에 도구 시간이 들어가 연속6키도 약1.3초 이상 간격이었다. sub300ms 실제 키 연타는 검증했다고 하지 않으며, 빠른 교체·취소·지연 응답은 제어된 ViewModel 테스트 근거다. 한글 글자 판별이나 Search 버튼 강제 정책을 추가하지 않았다.

## 2. ordinary Release 기본 OFF / ON

최종 [OFF 저장값과 연속 network 관측](release-off-network.log)은 2026-10-23T15:03:21Z부터 앱 종료까지다. PID98422 시작 전 stream을 켰고, 저장 dictionary에서 `study.search`를 제거했다. auth.google-login=false와 repositoryMode=real은 보존했다. [검색 진입점 없음](release-default-off.png)을 확인했으며 유일한 URLSession task1은 Main 목록의 HTTP200이다. 검색 task는0개였다.

[ON 대조](release-on-network.log)는 동일 Release PID49039다. task1은 Main, task2–4는 실제 검색 조작, task5는 선택한 상세이며 모두 HTTP200이다. [검색 결과](release-search-content.png)와 [실제 상세](release-selected-detail.png)를 확인했다. CFNetwork의 path/query는 OS에서 redacted되므로 요청 수·시각, 실제 화면, 소스의 OFF guard를 함께 근거로 사용한다. HTTP 본문 전체는 저장소 증거에 넣지 않았다. 이 관측은 위 앱 실행 구간의 무요청 검증이다.

처음 plist 파일을 직접 고친 ON 시도는 CFPreferences cache 때문에 반영되지 않았다. 이를 ON 성공으로 세지 않았다. 지정17e의 정확한 앱 container를 `SIMCTL_CHILD_CFFIXED_USER_HOME`으로 지정한 `simctl spawn defaults` CFPreferences 경로로 교정했다. 최종 OFF도 그 경로로 다시 검증했다. 마지막에는 원래 auth=false/search=true/repositoryMode=real 값을 모두 복구해 원본 plist 값과 동등함을 검사했다. 정책 기본값과 host/global preferences는 바꾸지 않았다.

## 3. 검색 전용 transport 실패 → 실제 배포 성공

r1의 임시 Session/URLProtocol은 앱 Documents의 `sc78-search-network-fault` marker가 있고, GET·정확한 배포 host·`/api/studies`·keyword가 모두 일치할 때만 `URLError.notConnectedToInternet`을 반환한다. Main·상세·인증 요청이나 서버/호스트 네트워크는 건드리지 않았다. Repository 대역과 구분한다.

- marker 생성 2026-10-23T14:47:52Z. keyword=스터디, status=CLOSED, category 없음, offset0, limit20에서 [실패·다시 검색](search-transport-failure.png)을 확인했다. Unix1792766886.560537의 FAULT와 status=-1/bytes0을 보존했다.
- marker 제거 2026-10-23T14:48:20Z. 필터·검색어를 바꾸지 않고 실제 `다시 검색`을 눌렀다. Unix1792766907.200344 요청 →1792766907.771432 HTTP200 / body7587bytes / decoded20 / total34와 [실제 배포 결과](search-deployed-retry-success.png)를 확인했다. marker가 없으면 URLProtocol은 개입하지 않고 Alamofire의 실제 transport·decode 경로를 따른다.
- 서버 장애를 재현한 증거는 아니다. 배포 host를 쓰는 실제 앱의 client transport 실패·동일 조건 재시도 복구 증거다. marker는 제거했고 임시 Session/helper도 최종 제품에서 제거했다.

## 4. 제목·목록·상세 복귀

무수정 기준의 [전](baseline-compact-before.png) / [후](baseline-compact-after.png)는 같은 DDIA 위치에서 compact 제목이 사라진다. 최종 ordinary Release는 다음 상태를 실제 simctl PNG로 검수했다.

| 경로 | 전 | 후 |
|---|---|---|
| 상단 검색·응답·취소 | [large](release-large-before.png) | [large와 목록 유지](release-large-after-cancel.png) |
| 중간 검색·응답·취소 | [compact](release-compact-before.png) | [compact와 카드 위치 유지](release-compact-after-cancel.png) |
| 재진입·선택·상세·뒤로 | [실제 상세](release-selected-detail.png) | [원래 compact·목록 복귀](release-compact-after-detail-back.png) |

r1의 BEGIN/DISMISS 로그는 snapshot ID `[21,20,19,18]`, offset `(0,5)`, adjusted inset top161/bottom83이 같다. ordinary 캡처의 DDIA·후속 카드 위치도 같다. 내부 UIKit 원인을 확정하지 않으며, 복원된 offset에 맞춰 navigation layout을 다시 계산하는 공개 API 수정이다.

CUA의 즉시 반환 프레임에는 전환 중 제목이 잠시 없었다. 이를 실패로 오판한 뒤 같은 직후 저장된 simctl PNG를 열어 제목이 있음을 확인해 정정했다. run의 `ordinary-release-navlayout-failed.png`는 잘못 붙인 파일명이며 보존했다. 이후 source 변경은 없다. read-only LLDB hierarchy도 정상 title label/frame을 확인한 보조 자료이며 별도 화면 성공을 대신하지 않는다. 전체 chrome 픽셀 일치를 주장하지 않는다.

## 빌드·테스트·보관

최종 ordinary source에서 Debug/Release Simulator build exit0, ad-hoc 서명한 직렬 XCTest **212/212 통과·실패0·건너뜀0·exit0**이다. [원시 summary](tests-summary.json)를 보존했다. UI 자동 테스트나 app-defined accessibility identifier는 추가하지 않았다.

```sh
xcodebuild -project ios/studyclub.xcodeproj -scheme studyclub -configuration Debug \
  -destination 'platform=iOS Simulator,id=8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1' \
  -derivedDataPath /tmp/studyclub-search-r1/DerivedData \
  -resultBundlePath /tmp/studyclub-search-r1/sc78-final-full.xcresult \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -quiet
```

첫 임시 probe build2회는 관측 코드의 Foundation import/다중 문장 return 누락으로 실패했다. 로그를 `/tmp/studyclub-search-r1/sc78-instrumented-build*.log`에 보존했고 교정 후 probe 및 ordinary 빌드가 통과했다. 제품 오류나 성공 테스트로 분류하지 않았다.

한 build/device writer로 기존 DerivedData·17e를 재사용했다. 다른17Pro에는 입력·설치·종료하지 않았다. Simulator/XCTest 데이터나 preexisting artifact 삭제는 없었다. Orca17e helper는 종료했고, raw CFNetwork·빌드 로그·xcresult·LLDB 진단은 task 경로에 보존했다. 저장소에는 작은 캡처·summary·최소 이벤트/transport 자료만 둔다. [파일 hash 목록](sha256.json)을 함께 둔다.
