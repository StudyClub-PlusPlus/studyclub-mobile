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
- Setting contains a large “설정” title and an empty native list until settings content is specified.

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

## Development Settings

Debug-only SwiftUI modal hosted by UIHostingController, with its own NavigationStack title and Close button. Use an inset-grouped SwiftUI List with “기타”, “Ready”, “InProgress” headers. The miscellaneous section has a Repository button displaying Mock/Real and a separate Reset Flag to Default button. Repository opens a mode alert; a changed selection closes the modal and recreates the tab navigation stacks on Main. The saved mode applies to Debug only, while Release always uses Real. Flag rows use a wrapping name on the left and a labeled switch on the right; the full row is also tappable. Ready defaults ON and InProgress defaults OFF. Empty flag sections keep their headers. Reset updates switches in place without recreating the app root.
