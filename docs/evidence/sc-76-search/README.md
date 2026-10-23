# SC76 검색 구현·검증 · 2026-10-23

후속 실제 키보드·ordinary Release OFF/ON·검색 전용 transport 복구·제목 수정 근거는 [SC78](../sc-78-search-qa/README.md)에 있다. 아래 SC76 당시 기록과 미검증 범위는 원문으로 유지한다.

검색은 로그인과 독립적인 `study.search` InProgress·기본 OFF로 구현했다. SC74/75/77은 각각 PR20/21/24로 main에 반영됐다. SC76은 main `ec7bd5e80e18aba47dc895304797f9caf7b6f13f` 위 1커밋이다. Ready 전환은 하지 않았다.

## 후보와 환경

- 최종 실행 코드: `899007c302db6bfe9567f31aba3b3c1c929cb4ac`. 이후 이 디렉터리의 증거 파일만 추가한다.
- ios tree `838b42d0d22f56459b4aca1deefa273c86793f89`; app tree `d064198b457510d533521de4f3f77418541ce45c`; tests tree `9855162e7c13eb43f9ec2f299a9dd121fdb07cae`.
- Xcode27.0(27A266a), iPhone17e/iOS26.5/23F77, UDID `8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1`, bundle `studycub.studyclub`.
- 단일 build/device writer와 전용 `/tmp/studyclub-search-r1/DerivedData`를 사용했다. 다른 작업의 iPhone17Pro에는 입력·설치·삭제·종료를 하지 않았다. 새 Simulator/worker clone을 만들지 않았다.
- Debug Real, 검색 ON override / 로그인 OFF / MyPage·내 스터디 OFF로 실제 검색을 확인했다. Release는 Real이며 같은 검색 ON override를 읽었다. **기본값은 여전히 OFF**다.

## 빌드와 테스트

최종 source899007c에서 다음을 실행했다.

```sh
xcodebuild -project ios/studyclub.xcodeproj -scheme studyclub -configuration Debug \
  -destination 'platform=iOS Simulator,id=8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1' \
  -derivedDataPath /tmp/studyclub-search-r1/DerivedData \
  -resultBundlePath /tmp/studyclub-search-r1/sc76-final-full.xcresult \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -quiet
```

- **212/212 통과, 실패0, 건너뜀0, exit0**. [원시 XCTest summary](tests-summary.json). 검색9개는 입력·조합·삭제·취소·필터와 늦은 응답, 페이지 offset/중복/재시도/진행 불능을 제어된 Repository 응답과 기대값으로 검사한다. 테스트에 sleep/yield polling은 없다.
- ordinary Debug 및 Release Simulator build exit0. Release는 임시 대역 제거·원문 byte 복구 후 빌드·설치·실행했다.
- 최종 테스트 Debug dylib SHA256 `f5fc9b59f8e3cd30b4a7fa959431474e8f8123a5520b96161b28326721b91ed0`.
- ordinary Release executable SHA256 `da11a8c4a570fa229320907d6d7ddcd2ff93f5d3b7135e1fabebe90a7161b934`.

앞선 source9ef004의 첫 전체 실행은 CODE_SIGNING_ALLOWED=NO여서 Keychain 두 TC에서 -34018/3 assertion 실패가 났다. linker 서명만 있고 Info.plist binding과 sealed resources가 없는 실행 환경이었다. 원시 stdout은 `/tmp/studyclub-search-r1/sc76-unsigned-test-stdout.txt`에 보존했다. 전체212개 실행 종료를 확인한 뒤 진단 수집만 남은 해당 xcodebuild/자식 diagnose를 중단했다. 제품 코드를 바꾸지 않고 정상 Simulator ad-hoc 서명으로 교정한 source358ab9 실행이 212/212 통과했고, 최종 스크롤 수정 뒤 source899007c에서도 212/212를 다시 확인했다. 실패를 삭제하거나 성공으로 분류하지 않았다.

## 실제 UI·공개 API 근거

| 범위 | 관측과 캡처 | 후보 |
|---|---|---|
| 독립 플래그 | [검색ON·로그인OFF·Real](debug-real-search-on-auth-off.png) | Debug358ab9 |
| 빈 입력 | [필터만 보임](debug-real-initial.png); EmptyView 없음 | Debug358ab9 |
| 자동 갱신·0건 | Search 버튼 없이 ASCII Swift 입력 → [0건](debug-real-empty.png) | Debug358ab9 |
| 한국어 검색 | AX setValue 스터디 → [실제 결과](debug-real-content.png), 초기20/total38 | Debug358ab9 |
| 페이지 | 더 보기 후 [마지막 Business Articles까지](debug-real-last-page.png); 더 보기 종료 | Debug358ab9 |
| 필터 | [종료+소프트웨어](debug-real-filtered.png), 서버 공개 필터 응답7건과 일치 | Debug358ab9 |
| 삭제·유지 | [검색어 삭제 후 빈 화면과 선택 필터 유지](debug-real-cleared-filters-retained.png) | Debug358ab9 |
| ID 직접 전달 | 기본 모집 목록에 없는 종료86 선택 → [로봇 AI 실제 상세](debug-real-closed-id86-detail.png) | Debug358ab9 + SC77 |
| 취소·보존 | [전](debug-real-browse-before-search.png) / [후](debug-real-browse-after-cancel.png); DDIA와 후속 카드의 상대 위치 유지 | 최종899007c와 동일 코드 |
| ordinary Release | [실제 공개 Main과 검색 진입점](release-real-main-search-on.png) | Release899007c |

358ab9와899007c의 Search ViewModel·결과 VC·API 코드는 동일하다. 최종 변경은 Main이 offset을 저장하는 시점을 willPresent에서 최초 searchBarShouldBeginEditing으로 앞당긴 것이다. 탄성 스크롤이 멈춘 상태에서 검색→Swift 응답→취소의 카드 위치를 다시 확인했다. UIKit의 접힌 제목 표현은 달라질 수 있어 전체 chrome의 픽셀 일치를 주장하지 않는다. Main snapshot/필터는 검색으로 교체하지 않는다.

입력 방식은 ASCII typeText와 한국어 AX setValue다. **한국어 문자열 성공을 markedTextRange IME 조합 성공으로 해석하지 않는다.** 기존 17e 입력 표면에서 영문 키와 Emoji를 관측했으며 호스트 키보드 설정이나 다른 기기를 바꾸지 않았다.

## 제어된 상태와 원문 복구

기존 MockRepository는 실패·지연을 만들지 않는다. 화면 확인용으로만 Search ViewModel의 factory1줄과 임시 Domain Repository를 사용했다. [정확한 factory patch](controlled-factory.patch), [임시 대역 원문](controlled-repository.txt)은 이 증거 디렉터리의 텍스트 자료이며 앱 target에 포함하지 않는다.

- 대역은4초 대기 후 keyword=failure에서 unavailable을 던진다. [실패·다시 검색](controlled-failure.png)와 실제 버튼을 누른 뒤 [로딩](controlled-loading.png)을 확인했다. 실제 서버 장애·재시도 성공을 뜻하지 않는다.
- controlled Debug dylib SHA256 `e3658ef1e9f181b2a90c862c7b91494cdd042b2cd19936d63a59da0215a7dd17`.
- helper SHA256 `ec110f75e7ef9258804c9d726d7f9f2857d7175d9bf14fc5a715e5988fb104da`; factory patch SHA256 `72f0fec785b023dae140b99f3515f7f9ce651c8aef4a4c6d00c5bf6baf13bcc8`.
- 로딩 PNG는16.3267초 native 기록의12.245초 프레임이다. 원본 `/tmp/studyclub-search-r1/controlled-retry.mp4` SHA256 `94c992d9769f87fe80a0e2121ec6c59783f6df57f328f3525c4773f301f0031c`.
- 빌드 종료 후 factory를 보관 원문으로 byte 복구하고 임시 app source 파일을 제거했다. `git diff --exit-code -- ios`=0과 app tree d064198…을 확인한 뒤 ordinary Release를 빌드했다. Debug 제품도 ordinary source로 재빌드해 임시 대역 제품을 남기지 않는다.

DeviceHub가17Pro 창으로 전환된 것을 read-only 상태에서 감지해 입력을 멈췄다. Window 메뉴의 기존17e와 Raise로만 복구했고 새 창·기기 생성이나17Pro 조작은 없었다. 뒤의 Close 요청은 CUA30초 timeout/kernel reset으로 효과가 불확실했다. 추가 복구를 반복하지 않고 정확한17e UDID로 ordinary Release를 설치·실행했다. 마지막 앱은 임시 대역이 아니다.

## Ready 전 남은 확인

- 실제 한국어 IME의 조합 중/완료 UIKit callback과 키보드 조작 검증.
- 안정된 호스트 UI에서 ordinary Release 검색 OFF cold-launch 진입 비노출·미호출과 Release 검색 조작 재확인. OFF guard·unit 결과와 초기 SC74 설정 캡처는 있으나 최종 Release OFF native 완료로 확장하지 않는다.
- 실제 배포 환경의 장애·재시도와 기기/키보드 QA. 제어된 실패 캡처와 공개 검색 성공을 배포별 Ready 승인으로 사용하지 않는다.
- 취소 뒤 UIKit navigation chrome 표현의 최종 기기 검수. 스크롤 카드 위치·snapshot 보존과 구분한다.

위 항목은 #96/SC76에 남긴다. 소스의 InProgress·기본 OFF를 유지하고 Ready/배포 완료로 보고하지 않는다. 최종 merge는 부모가 독립 리뷰 뒤 수행한다.

## 보관

작은 PNG·원시 테스트 summary만 저장소에 보존했다. task 전용 DerivedData 약1.5GiB, failed xcresult 약47MiB, 성공 xcresult 각2.4MiB와 원본 clip/로그는 `/tmp/studyclub-search-r1/`에 둔다. 기존 simulator·XCTest device 데이터는 지우지 않았다. 모든 xcodebuild·녹화는 종료 후 확인하고 device/build lease를 부모에게 반환한다.
