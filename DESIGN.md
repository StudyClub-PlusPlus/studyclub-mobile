# StudyClub iOS Design System

## Brief

The first StudyClub surface should look like a calm, native reading list rather than a decorative prototype. The visual direction combines Apple-native UIKit behavior with restrained editorial spacing. It uses live UIKit components and reusable tokens; no screenshot, illustration, or generated image stands in for interface elements.

## Design references

- Layer A: premium utilitarian minimalism — restrained borders, generous space, muted accents, almost no shadow.
- Layer B: Apple-native system language — semantic colors, SF typography through Dynamic Type, clear navigation chrome, and familiar control behavior.
- Web-only browser, Lighthouse, and responsive-page gates are not applicable. The equivalent native gates are Simulator rendering, trait-safe semantic colors, Dynamic Type, VoiceOver metadata, and compact/regular width checks.

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
- Cell content is self-sizing and supports Dynamic Type

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

- Main and Detail each start one request when their ViewModel is initialized.
- Tapping any visible card pushes exactly that item’s Detail.
- Use standard navigation transitions and system highlight behavior. Do not add decorative entrance animations.
- Respect Reduce Motion automatically by relying on UIKit system transitions.

## Accessibility

- All text uses Dynamic Type and can wrap without clipping.
- Cards expose a combined label and the button trait; the disclosure image is decorative.
- State images are hidden from VoiceOver when the adjacent text conveys the same meaning.
- Future interactive controls require explicit labels and at least 44 by 44 points.
- Color never carries status alone. Light and dark appearances use semantic colors.
- Korean copy must not clip, truncate important nouns, or leave single particles on isolated lines at accessibility text sizes.

## Visual QA contract

Enumerate and capture these surfaces after the last UI edit:

1. Main content
2. Detail for the second study
3. Main empty
4. Main failure
5. Main loading

Check safe areas, card alignment, Korean wrapping, dark-mode semantics, Dynamic Type behavior, VoiceOver metadata, state exclusivity, and correct Detail content. Any blocking finding must be fixed and re-captured before completion.

## Accepted debt

- No bespoke imagery or remote image loading in the architecture scaffold.
- No iPad-specific multi-column composition yet; the one-column layout remains readable in regular width.
- Full VoiceOver interaction is a manual follow-up if the available Simulator automation cannot exercise the screen reader; labels and traits are still source-reviewed now.
