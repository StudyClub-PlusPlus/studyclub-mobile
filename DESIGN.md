# StudyClub iOS Design System

## Brief

When `study.design-system` is ON, the existing guest list uses readable, self-sizing cards with the team's Figma green/cream palette. The user selected the card hierarchy and light-only appearance for sc-116 on 2026-10-03 after research and independent development review. UIKit navigation, system fonts and the existing display/data contracts remain in place; no screenshot, illustration, or generated image stands in for interface elements.

## Rollout boundary

`study.design-system` is InProgress and defaults OFF in Debug and Release. OFF preserves the previous system palette, category badge/separate status card, unlimited summary, Detail spacing/divider behavior and OS-adaptive appearance. ON enables the design described below, including light-only appearance.

AppTheme resolves the flag through the existing concrete DevelopmentSettingsStore once per app process. The same immutable decision gates palette, card anatomy, Detail polish and scene-window appearance. Changing the Debug switch or resetting flags affects the next cold launch; switching tabs, opening Detail or rebuilding the root after a Repository change does not mix designs in the current process. The switch name states that an app restart is required. No mutable theme override or new flag catalog is introduced.

## Design references

- [Team Figma Color Scheme](https://www.figma.com/design/2K09lEbASPTPqpAlKuyjAt?node-id=54-40): cream canvas, white surface, dark text and green accents. These are source colors, not an approved iOS screen specification.
- UIKit: preferred text styles, self-sizing cells, standard navigation and tab behavior, restrained borders and no default shadow.
- Frozen FE source and Storybook are structural comparisons. Their indigo palette is not mixed into this selected Figma direction. Source versions, mapping and exclusions are recorded in [the sc-116 token map](docs/design/SC_116_TOKEN_MAP.md).
- With the design flag ON, app appearance is light-only, owned by the scene window before root creation. A dark OS setting should still produce light app screens and hosted modals; this needs native observation. Window appearance does not establish launch-screen behavior.

## Tokens

Use the shared `AppTheme` source rather than one-off values. The selected values below are the ON palette; OFF returns the original dynamic UIKit colors.

- Canvas: Figma Light Bg `#FAF9F5`
- Primary surface: Figma Surface `#FFFFFF`
- Primary text: Figma Text/Body `#252522`
- Secondary text: Figma Text/Subtle `#6B6A64`
- Accent/action: Figma Dark Green `#596F22`
- Pressed surface: Figma Light Green `#EFF6D8`, assigned this interaction role by the app
- Border: Figma Border `#E5E3DC`, full opacity and one physical pixel for cards
- Error accent: `systemRed`
- Spacing scale: 4, 8, 12, 16, 20, 24, 32
- Radius scale: 8 for small controls, 16 for cards
- Type: UIKit preferred text styles only; titles use headline/title styles, metadata uses subheadline/caption
- Shadow: none by default; surface and border establish hierarchy

## Main anatomy

- The app root has two native tabs: “스터디” and “설정”, each with its own navigation stack. Tab switching retains the Main → Detail stack.
- Setting contains a large “설정” title. `auth.google-login` OFF keeps the empty native list. ON shows the account display states described below. Study/Settings tabs and public Main → Detail stay unchanged.

- Large navigation title: “스터디”
- No added hero or introduction in this slice
- One-column adaptive card list with readable content margins
- Card: neutral, wrapping category/status text; full title; up to two lines of summary; wrapping member information and disclosure indicator
- Empty category/status parts omit their separator; empty summary closes its block and spacing. Status strings are not parsed into urgency or recruiting colors.
- Outer inset 16, inter-card gap 12, inner padding 20, radius 16. Title-to-summary gap 8; summary-to-footer gap 16. These are native adaptations using the existing spacing scale, not Figma mobile specs.
- Cell content is self-sizing

## State anatomy

Main list OFF omits pull-to-refresh, pagination and footer UI and keeps a one-request surface. Real OFF shows a neutral info symbol with “아직 제공되지 않는 기능이에요” and “스터디 목록은 준비 중이에요.”, separately from empty or failure. Debug Mock OFF shows its current trusted first-page samples. ON keeps pagination/refresh UI. Feature values are fixed when the screen is created. Detail Real OFF preserves its previous failure surface without an API request; Mock detail remains unchanged.

- Loading: centered activity indicator and short Korean status label
- Empty: neutral system symbol, “아직 열린 스터디가 없어요”, and supporting copy
- Failure: error system symbol, “목록을 불러오지 못했어요”, and supporting copy
- State surfaces replace the collection content and remain centered inside the safe content area
- Retry and reload controls are deferred to later common ErrorView work

## Detail anatomy

- Standard back navigation and inline title
- Scrollable readable column
- Neutral wrapping category, full study title, existing kind/format/capacity/recruitment metadata, optional schedule, description and curriculum
- Empty optional blocks close their spacing. The curriculum divider, heading and body are hidden together when curriculum is absent.
- Content comes from the independently fetched Domain model for the selected ID.
- List summary and Detail description are separate values; Detail is not promised to recover the full list summary.
- Detail uses the existing state surface for loading, empty (“스터디를 찾을 수 없어요”) and failure with detail-specific Korean copy. Failure has no retry button and directs the user back; common ErrorView work is deferred. Content and state surfaces are mutually exclusive.

## Interaction

- In Debug builds only, holding the Main tab item for 0.7 seconds opens Development Settings in a modal navigation stack with a Close button. Normal taps and holding Setting do not open it. Release compiles out the gesture and screen.

- Main and Detail each start one request when their ViewModel is initialized.
- Tapping any visible card pushes exactly that item’s Detail.
- Use standard navigation transitions and system highlight behavior. Do not add decorative entrance animations.

## Current accessibility scope

Custom accessibility labels, traits, announcements, special large-text layouts, and dedicated accessibility QA are deferred. Preserve native control behavior and existing system fonts. Do not add accessibility identifiers; verify native controls manually on Simulator.

## Visual QA contract

Enumerate and capture these surfaces after the last UI edit. These are acceptance targets, not a record that QA has passed:

1. Main content
2. Detail for the second study
3. Main empty
4. Main failure
5. Main loading
6. Main Real list OFF unavailable and Debug Mock list OFF content, with no refresh or footer
7. Detail empty, failure and loading
8. With the design flag ON, light appearance under dark OS settings, including Setting, navigation/tab chrome and the Debug hosted modal/alert
9. With the design flag OFF, original card/detail layout and dynamic system palette under light and dark OS settings; toggle/reset must take effect only after cold launch
10. Release also reads saved overrides; without one, the design system remains OFF

Check safe areas, card alignment, long Korean title/metadata wrapping, empty summary, state exclusivity, optional Detail blocks, pressed feedback and stable-ID navigation. Record exact source candidate, bundle/device/OS, input provenance and captures. Controlled component renders establish only that surface; they do not establish live API transitions or installed-app navigation. Do not add permanent scenarios, verification-only flags or automatic UI/internal-settings tests for this verification. Any blocking finding must be fixed and re-captured before completion.

## Accepted debt

- No bespoke imagery or remote image loading in the architecture scaffold.
- No iPad-specific multi-column composition yet; the one-column layout remains readable in regular width.

## 설정 계정 영역 View · SC-56

`SettingViewController`는 큰 “설정” 제목과 네이티브 insetGrouped 목록을 사용한다. `auth.google-login`은 InProgress이며 기본 OFF다. OFF에서는 계정 그룹과 로그인 진입을 숨긴다. ON에서는 기존 ViewModel의 표시 상태를 읽는다.

- 비회원은 설명과 이동 표시가 있는 로그인 행을 표시한다. 확인 중에는 이름 없이 상태 설명과 네이티브 진행 표시를 보여 준다. 상태 확인 실패는 설명과 “다시 확인”을 같은 그룹에 둔다.
- 회원은 확인된 닉네임과 “로그인됨”을 계정 그룹에 표시한다. 이름 행은 이동 표시·아바타·편집 동작이 없다. “로그아웃”은 제목이 없는 별도 행동 그룹이다.
- 로그아웃 실패는 회원 정보를 유지한다. 별도 행동 그룹에 실패 설명과 “로그아웃 다시 시도”를 표시한다. 로그아웃 확인은 네이티브 알림의 취소·파괴적 로그아웃 동작을 유지한다.
- 행은 내용에 맞춰 높이가 늘어나며 이름과 상태 문구는 여러 줄을 허용한다. section과 행은 안정적인 diffable 식별자를 사용한다. 선택은 현재 식별자로 처리하고 실행 전에 인증 플래그와 허용 동작을 다시 확인한다.
- 디자인 플래그 ON은 기존 AppTheme의 cream 배경·흰 그룹·green 강조를 사용한다. OFF는 시스템 light/dark 색상을 따른다. 네이티브 목록·진행 표시·알림을 재사용한다.

로그인·재확인·로그아웃은 기존 콜백만 전달한다. 연결되지 않은 콜백은 추가 안내 없이 동작하지 않는다. SC-52가 실제 세션 확인과 인증·로그아웃 결과를 연결하며 이 View 작업은 API·인증·저장을 수행하지 않는다. 제어된 native 렌더와 임시 호스트의 Simulator 조작은 실제 Google/API 동작·공개 인증 진입·최종 QA의 증거가 아니다.

## Development Settings

Debug-only SwiftUI modal hosted by UIHostingController, with its own NavigationStack title and Close button. Use an inset-grouped SwiftUI List with “기타”, “Ready”, “InProgress” headers. The miscellaneous section has a Repository button displaying Mock/Real and a separate Reset Flag to Default button. Repository opens a mode alert; a changed selection closes the modal and recreates the tab navigation stacks on Main. The saved mode applies to Debug only, while Release always uses Real. Flag rows use a wrapping name on the left and a labeled switch on the right; the full row is also tappable. Ready defaults ON and InProgress defaults OFF. Empty flag sections keep their headers. Reset updates switches in place without recreating the app root.

## 가입 정보 입력 View · SC-55

`OnboardingViewController`는 공개 앱 진입점에 연결하지 않은 UIKit 화면이다. 닉네임·시간대·동의를 하나의 스크롤 폼에 표시한다. AppTheme 색상과 간격, 최대 560pt 읽기 폭, 키보드 위 스크롤 영역을 사용한다. 입력·주요 버튼은 최소 50pt, 문서 버튼은 최소 44pt다.

승인된 B 방향에 따라 닉네임과 시간대를 하나의 테두리 그룹에 두고 구분선으로 나눈다. 필수 동의와 선택 동의는 제목과 그룹을 각각 가진다. 각 동의는 줄바꿈하는 문구와 네이티브 UISwitch로 표시하며 문서 버튼은 해당 행 아래의 독립된 동작이다. 행 높이는 문구에 맞춰 늘어난다. 닉네임 오류는 입력 바로 아래에 기호와 설명으로 표시한다. 폼 끝의 상태 영역은 처리·재확인·실패 설명을 표시하고, 내용이 없으면 접힌다. 글꼴은 preferred text style, 색상은 기존 AppTheme ON의 green/cream과 OFF의 동적 시스템 색상을 사용한다. 시간대 목록도 같은 표면·문구·선택 색상을 사용한다.

- 추천 닉네임은 하드코딩한 `스터디친구`다. 시간대는 유효한 기기 IANA 식별자를 사용하고 유효하지 않으면 `Etc/UTC`로 표시한다. 시간대 목록은 안정적인 식별자로 선택한다.
- 필수 연령·이용약관·개인정보 동의와 선택 마케팅 동의는 모두 OFF로 시작한다. 필수 항목과 공백이 아닌 닉네임이 있어야 제출할 수 있다. 닉네임에 정규식·길이 제한·자동 공백 제거를 적용하지 않는다. 입력 중 한글 조합을 다시 대입하지 않는다.
- 별도 문서 버튼은 engineering `core-front/src/lib/legal.ts`의 기존 이용약관·개인정보 처리방침 전문을 표시한다. 마케팅 안내는 같은 웹 가입 화면의 이메일 수신 문구를 사용한다. 개발용 임시 설명은 표시하지 않는다. 입력과 동의는 메모리에만 있으며 API·인증·가입 저장은 수행하지 않는다.
- `OnboardingViewModel`은 편집·제출 중·완료 여부 불확실·재확인 중·닫힘을 표시한다. 제출 중에는 입력을 잠근다. 불확실하면 “다시 확인”만 제공하고 재제출하지 않는다. 명확한 실패 또는 미완료 확인을 전달받으면 입력을 유지한 편집 화면으로 돌아간다.
- 변경된 입력이나 제출 상태에서 닫기는 확인 창을 표시한다. 닫으면 입력을 지우고 닫힘 상태로 바꾸며 이후 표시 결과를 받지 않는다. 확인 창은 이미 보낸 요청의 취소를 약속하지 않는다.

SC-52는 `onSubmit(Input)`·`onRecheck()`·`onClose()`를 실제 인증 흐름에 연결하고 실제 인증 흐름에서 사용할 정책 자료와 배포 계약을 연결한다. 기존 원문 출처와 개정일은 `AuthDocuments.swift`에 기록한다. SC-55의 로컬 스위치와 제출 표시를 실제 가입으로 해석하지 않는다. 상태별 제어된 렌더와 임시 호스트의 Simulator 조작은 공개 앱 진입점·실제 인증·최종 QA를 증명하지 않는다. 리드는 같은 최종 후보의 diff와 시각 자료를 검토한다.
