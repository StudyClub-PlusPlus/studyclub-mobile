# StudyClub iOS Design System

## Brief

The first StudyClub surface should look like a calm, native reading list rather than a decorative prototype. The visual direction combines Apple-native UIKit behavior with restrained editorial spacing. It uses native components and reusable tokens; no screenshot, illustration, or generated image stands in for interface elements.

## Design references

- Layer A: premium utilitarian minimalism — restrained borders, generous space, muted accents, almost no shadow.
- Layer B: Apple-native system language — semantic colors, system typography, clear navigation chrome, and familiar control behavior.
- Web-only browser, Lighthouse, and responsive-page gates are not applicable. The equivalent native gates are Simulator rendering, trait-safe semantic colors, and compact/regular width checks.

## Tokens

Use the shared `AppTheme` source rather than one-off values.

- Canvas: `systemGroupedBackground`
- Primary surface: `secondarySystemGroupedBackground`
- Primary text: `label`
- Secondary text: `secondaryLabel`
- Accent/action: `systemIndigo`
- Border: `separator` at low alpha
- Error accent: `systemRed`
- Spacing scale: 4, 8, 12, 16, 20, 24, 32
- Radius scale: 8 for small controls, 16 for cards
- Type: UIKit preferred text styles only; titles use headline/title styles, metadata uses subheadline/caption
- Shadow: none by default; surface and border establish hierarchy

## Main anatomy

- The app root has two native tabs: “스터디” and “설정”, each with its own navigation stack. Tab switching retains the Main → Detail stack.
- Setting contains a large “설정” title and an empty native list until settings content is specified.

- Large navigation title: “스터디”
- Optional one-line introduction above the first card through section boundary spacing, not a hero panel
- One-column adaptive card list with readable content margins
- Card: small category label, study title, two-line summary, member/status metadata, disclosure indicator
- Cell content is self-sizing

## State anatomy

- Loading: centered activity indicator and short Korean status label
- Empty: neutral system symbol, “아직 열린 스터디가 없어요”, and supporting copy
- Failure: error system symbol, “목록을 불러오지 못했어요”, and supporting copy
- State surfaces replace the collection content and remain centered inside the safe content area
- Retry and reload controls are deferred to later common ErrorView work

## Detail anatomy

- Standard back navigation and inline title
- Scrollable readable column
- Category label, large study title, member/status metadata, summary, and “이 스터디에서 다룰 내용” section
- Content comes from the independently fetched Domain model for the selected ID.
- Detail uses the existing state surface for loading and failure with detail-specific Korean copy. Failure has no retry button and directs the user back; common ErrorView work is deferred. Content and state surfaces are mutually exclusive.

## Interaction

- In Debug builds only, holding the Main tab item for 0.7 seconds opens Development Settings in a modal navigation stack with a Close button. Normal taps and holding Setting do not open it. Release compiles out the gesture and screen.

- Main and Detail each start one request when their ViewModel is initialized.
- Tapping any visible card pushes exactly that item’s Detail.
- Use standard navigation transitions and system highlight behavior. Do not add decorative entrance animations.

## Current accessibility scope

Custom accessibility labels, traits, announcements, special large-text layouts, and dedicated accessibility QA are deferred. Preserve native control behavior and existing system fonts. Do not add accessibility identifiers; UI tests locate native controls by visible text.

## Visual QA contract

Enumerate and capture these surfaces after the last UI edit:

1. Main content
2. Detail for the second study
3. Main empty
4. Main failure
5. Main loading

Check safe areas, card alignment, Korean wrapping, dark-mode semantics, state exclusivity, and correct Detail content. Any blocking finding must be fixed and re-captured before completion.

## Accepted debt

- No bespoke imagery or remote image loading in the architecture scaffold.
- No iPad-specific multi-column composition yet; the one-column layout remains readable in regular width.

## Development Settings

Debug-only SwiftUI modal hosted by UIHostingController, with its own NavigationStack title and Close button. Use an inset-grouped SwiftUI List with “기타”, “Ready”, “InProgress” headers. Repository shows the current mode below its label and opens a mode picker. Reset Flag to Default is a button row. Flag rows use a wrapping name on the left and a labeled switch on the right; the full row is also tappable. Ready defaults ON and InProgress defaults OFF. Empty flag sections keep their headers. Reset updates switches in place. Repository changes close the modal and return to a freshly constructed Main tab.
