# sc-116 source-to-native mapping

User decision, 2026-10-03: Figma green/cream, self-sizing cards and light-only app appearance. Existing UIKit/Auto Layout, MVVM + Repository and native preferred fonts remain. This document specifies the selected mapping, not final visual QA or a team-wide design-system approval.

## Sources and limits

- [Team Figma file / Design System page 30:2](https://www.figma.com/design/2K09lEbASPTPqpAlKuyjAt?node-id=30-2), [Color Scheme frame 54:40](https://www.figma.com/design/2K09lEbASPTPqpAlKuyjAt?node-id=54-40), color instances 54:42–54:51. Read 2026-10-03; immutable published version unavailable. Browser variable panel showed no local variable collections; returned style values do not prove aliases or appearance modes.
- Surface node 54:51 was checked with style values and design context/screenshot: actual Surface is `#FFFFFF`. Printed `#FAFCFE` is separate text. Sample wrapper opacity 0.9 and inset shadow are not app-card values.
- [Frozen FE tokens](https://github.com/StudyClub-PlusPlus/studyclub-engineering/blob/94eb15f13c4b561e0d84ba77085c336365b25dad/frontend/packages/design/tokens.css) and its design-system.md were read as git objects. These files and Card/Badge/EmptyState were unchanged from `94d6eb351dfef240d2c8ee2fd86152784fa0ae05`. Web product StudyCard is distinct from the shared primitive.
- [Production Storybook](https://ds.studyclub-plusplus.com/?path=/docs/ui-card--docs) and [Stage](https://ds-stage.studyclub-plusplus.com/?path=/docs/ui-avatar--docs) were opened. Three computed color samples matched the FE indigo/cool-neutral palette; full parity and deployment commit were not verified. The user chose Figma for this app.
- Figma reference/research pages and subscribed community kits are not approved iOS screen designs. Card spacing, hierarchy and interaction role assignments below are app adaptations.

## Consumed roles

Keep consumers using AppTheme rather than screen-specific HEX values.

| AppTheme role | Selected source | Consumers / app interpretation |
| --- | --- | --- |
| canvas | Light Bg `#FAF9F5` | Main, Detail, ContentStateView, Setting |
| surface | Surface `#FFFFFF` | resting card |
| elevatedSurface | Light Green `#EFF6D8` | pressed card feedback; app-assigned role, not recruiting status |
| primaryText | Text/Body `#252522` | title, body and state title |
| secondaryText | Text/Subtle `#6B6A64` | summary, category/status/member facts and supporting copy |
| accent | Dark Green `#596F22` | existing selected tab, spinner and Debug SwiftUI tint; dark color name does not mean dark-mode token |
| border | Border `#E5E3DC` | card edge and Detail divider; card full opacity, display-scale stroke |
| error | existing UIKit systemRed | failure symbol; no Figma error semantic was confirmed |
| spacing/radius | existing 4/8/12/16/20/24/32 and 8/16 | card inner20/outer16/gap12, native Detail reading rhythm |
| type | existing preferred UIKit text styles | native headline/subheadline/caption/title/body; no web font/pt conversion |

SceneDelegate owns light-only appearance once at window creation. Screen-level overrides, a new trait token resolver and a SwiftUI-only color scheme are unnecessary unless actual inheritance fails. Root replacement uses the same window. Hosted-modal/alert behavior remains a runtime observation target.

## Exclusions and completeness

Bright Green `#A6C83A` and pink Accent `#F06F8C` are retained as source references rather than new unused Swift constants. Pink was described for success/valid inputs, so it is not mapped to errors. Placeholder `#898880` is not used for meaningful metadata. LightGreen supplies only the pressed surface; no lifecycle meaning is inferred from status display strings.

FE indigo/cool neutrals, lifecycle badge colors, chart/attendance/role colors, web focus/hover/shadow/rem/letter-spacing, gradients, thumbnails, application/progress/bookmark UI and unused controls are excluded because they are a conflicting palette, web behavior or absent current consumers. Figma fonts describe source styles; UIKit preferred fonts remain the agreed app choice. Brand dark mapping is excluded by the user's light-only decision. No parallel design framework or new library is introduced.

All current AppTheme palette/spacing/radius consumers should be inspected in the final diff and native walkthrough. That is completeness for the selected app scope, not wholesale replication of every team token. API/DTO/Repository/Domain/ViewModel formatting and stable IDs remain outside this design change.
