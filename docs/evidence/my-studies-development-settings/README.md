# SC70 개발 설정 화면 근거

2026-10-22, iPhone 17 Pro / iOS 26.5 / 기본 글자 크기에서 직접 실행하고 화면을 확인했습니다. 모든 화면의 데이터는 테스트용입니다.

- SC70 소스 후보: `52fc269e3291e3c13fe43b8e5578196e19bedc6c`, iOS tree `fee900b94441573f7198af855d2ecce567deacbc`.
- SC68의 변경 없는 후보 `8d941a287a1611f40046585af04d1559d78402ea`와 SC70을 합친 실행 후보: `1dfadc8200889e4d7b79b11360399d361e99f02e`, iOS tree `e7ae33181687a57952fc0f6e7a031faf2f890d10`.
- 이 근거 파일을 추가한 커밋은 문서·이미지만 추가합니다. iOS 소스는 위 후보와 같습니다.
- SC70 단독 Debug 빌드와 통합 후보 Debug/Release 빌드 성공. 같은 통합 후보에서 `MemberAreaViewModelTests` 7개, `MyStudiesListIntegrationTests` 6개 성공. 모두 `-parallel-testing-enabled NO`로 같은 Simulator를 재사용했습니다.
- Debug 설치 파일 217개, Release 설치 파일 110개를 각각 빌드 제품과 SHA-256으로 비교했고 차이가 없었습니다.

| 확인한 행동 | 결과·화면 |
|---|---|
| Mock 상태 선택 | [선택창](mock-session-picker.png)에 실제 로그인을 하지 않는다고 안내합니다. |
| 회원 선택 | 루트를 새로 만들고 [회원 목록](member-list.png)을 표시합니다. 재실행 후에도 [회원 선택](member-settings.png)이 유지됩니다. |
| 비회원 선택 | 이전 회원 목록을 지우고 [로그인 안내](guest-list.png)를 표시합니다. |
| 회원 + 목록 플래그 OFF | [준비 안내](member-list-off.png)를 표시합니다. 상태 선택과 플래그는 별개입니다. |
| Real 전환 | 테스트 회원이 나타나지 않으며 [Mock 선택 행](real-settings.png)이 없습니다. |
| Release 실행 | 저장된 Mock/member 설정이 있어도 [실제 로그인 안내](release-profile.png)를 표시합니다. 스터디 탭 길게 누르기로 개발 설정이 열리지 않습니다. |
| 탭·프로필 | 각 탭에서 상세를 열고 탭을 바꿔도 각 탐색 스택이 유지됩니다. fullScreen 프로필을 닫으면 원래 탭으로 돌아갑니다. |

확인 범위는 로컬 Mock/실제 비로그인 화면과 관련 단위 테스트입니다. 실제 Google OAuth, 인증된 서버 목록 응답, 배포 QA는 확인하지 않았습니다. `study.my-studies`는 InProgress·기본 OFF로 유지하며 SC69 Ready 전환 근거로 사용하지 않습니다. 구현자가 수행한 직접 확인이며 별도 독립 리뷰를 뜻하지 않습니다.
