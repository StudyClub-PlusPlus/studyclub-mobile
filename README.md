# StudyClub Mobile

StudyClub의 iOS와 Android 앱을 같이 관리하는 모노레포입니다.

일단 iOS를 먼저 만들고, Android는 나중에 iOS 구현을 참고해서 AI로 옮길 생각입니다. 그래서 두 플랫폼의 코드와 문서를 한곳에서 관리합니다.

두 앱은 각각 네이티브로 만듭니다. 같은 저장소를 쓴다고 해서 Swift와 Kotlin 코드를 억지로 공유하거나, 두 앱을 항상 같이 배포하려는 것은 아닙니다.

## 왜 한 저장소에서 관리하나요?

iOS를 먼저 만들고 Android를 나중에 만들면, 그사이에 정해지는 내용이 생각보다 많습니다.

- 화면에서 어떤 상태를 보여주는지
- API 응답을 앱에서 어떻게 사용하는지
- 에러가 났을 때 어떤 문구와 다시 시도 동작을 제공하는지
- 목록을 눌렀을 때 어디로 이동하는지
- 어떤 테스트를 통과해야 기능이 끝난 것으로 볼지

저장소가 나뉘어 있으면 이런 내용도 같이 흩어지기 쉽습니다. 한 저장소에서 관리하면 iOS 코드, 관련 문서, 변경 이력을 Android 작업에서 바로 참고할 수 있습니다.

다만 Android는 iOS 코드를 줄 단위로 번역해서 만들지 않습니다. 두 앱에서 같아야 하는 동작만 맞추고, 화면 구성이나 생명주기, 비동기 처리 방식은 각 플랫폼에 맞게 구현합니다.

## 지금까지 만들어진 것

### iOS

- UIKit 기반 Main → Detail 화면
- Main 화면의 mock 목록
- Diffable Data Source와 Compositional Layout
- loading, content, empty, failure 상태와 retry
- MVVM + Repository 구조
- Swift Concurrency를 사용한 비동기 처리
- Combine의 Subject를 사용한 ViewModel → View 바인딩
- Alamofire를 사용하는 실제 API 연결용 코드
- mock API와 단위 테스트

현재 앱은 실제 서버가 아니라 정해진 mock 데이터를 사용합니다.

### Android

아직 시작하지 않았습니다. 첫 Android 작업을 시작할 때 `android/` 디렉터리와 프로젝트를 추가할 예정입니다.

지금은 KMP, 공통 Domain 모듈, 공유 UI 같은 구조를 넣지 않습니다. 두 플랫폼을 실제로 운영하면서 공유했을 때 이득이 분명한 부분이 생기면 그때 다시 판단합니다.

## 저장소 구조

```text
studyclub-mobile/
├── ios/                  # iOS 앱과 테스트
├── android/              # 예정: Android를 시작할 때 추가
├── docs/
│   ├── engineering/      # 아키텍처, 개발 규칙, 테스트 기준
│   └── product/          # 두 앱에서 같아야 할 화면 흐름과 동작
├── AGENTS.md             # AI가 작업하기 전에 확인할 내용
├── DESIGN.md             # 디자인 방향과 UI 기준
└── README.md
```

`android/`는 아직 없습니다. 실제로 Android 작업을 시작할 때 만들 예정입니다.

## 기능을 추가할 때

당분간은 다음 순서로 작업합니다.

1. iOS에서 기능을 작게 나누어 구현합니다.
2. 정상 화면만 보지 않고 loading, empty, failure, retry까지 확인합니다.
3. Android에서도 같아야 하는 화면 흐름과 데이터 처리 방식을 문서에 남깁니다.
4. Android를 만들 때는 iOS 코드와 문서를 참고하되 Android 방식으로 다시 구현합니다.
5. 두 앱의 화면 흐름, 에러 처리, 선택 결과가 같은지 테스트합니다.

두 플랫폼에서 맞춰야 하는 것은 사용자가 겪는 흐름입니다. 아래 구현까지 똑같이 만들 필요는 없습니다.

- 화면을 이동하는 방법
- UI 컴포넌트와 레이아웃 구성
- ViewModel 바인딩과 비동기 처리 방식
- 플랫폼별 시스템 아이콘과 애니메이션
- 앱 버전과 배포 일정

## iOS 구조

iOS는 다음 기준으로 구성합니다.

- UIKit + Code-based Auto Layout
- MVVM + Repository
- Domain / Data / Presenter 상위 레이어
- Swift Concurrency
- Combine Subject 기반 바인딩
- Diffable Data Source + Compositional Layout
- Alamofire + `URLRequestConvertible` Router
- DTO → Domain Model → ViewState
- ViewModel에서 RepositoryFactory로 Repository를 생성하고, 화면 전환 시에는 필요한 ID만 전달

자세한 내용은 아래 문서에서 확인할 수 있습니다.

- [iOS 아키텍처](docs/engineering/ARCHITECTURE.md)
- [개발 규칙](docs/engineering/CONVENTIONS.md)
- [화면 상태 처리 기준](docs/engineering/UI_STATE_POLICY.md)
- [기능 추가 가이드](docs/engineering/FEATURE_GUIDE.md)
- [테스트 기준](docs/engineering/TESTING.md)

## iOS 실행

```bash
open ios/studyclub.xcodeproj
```

Xcode에서 `studyclub` scheme과 설치된 iOS Simulator를 선택해 실행합니다.

## Android를 시작하기 전에 정할 것

Android 작업을 시작할 때는 바로 iOS 코드를 옮기기보다 아래 내용을 먼저 정합니다.

- 사용할 UI 방식과 최소 SDK
- navigation과 ViewModel 구성
- 의존성을 조립하는 방식
- iOS mock과 같은 상황을 재현할 테스트 데이터
- 두 앱에서 같아야 하는 동작과 Android에서 다르게 가져갈 부분

Android 프로젝트가 생기면 `ios/`와 `android/`는 각각 따로 빌드하고 테스트합니다. 한쪽 코드만 바뀌었다면 해당 플랫폼 검증만 실행하고, 두 앱의 공통 동작이 바뀌었다면 양쪽을 함께 확인하는 방식으로 CI를 구성할 생각입니다.

## 같이 보면 좋은 문서

- [AI 작업 가이드](AGENTS.md)
- [디자인 가이드](DESIGN.md)
- [AI 작업 인수인계 기준](docs/engineering/AI_HANDOFF.md)
- [Main / Detail 화면 동작 정리](docs/product/MAIN_DETAIL_SPEC.md)

지금은 작은 iOS 예제로 구조를 확인하는 단계입니다. 기능이 늘어나더라도 미리 큰 공통 모듈을 만들기보다, 실제로 반복되는 문제가 생겼을 때 필요한 만큼만 구조를 확장합니다.
