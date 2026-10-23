# Feature flag workflow

`study.search`는 로그인·목록 API 플래그와 독립적인 검색 플래그다. InProgress·기본 OFF이며 Debug와 Release 모두 기존 저장 override를 읽는다. 이 등록 작업은 검색 UI나 요청을 추가하지 않는다. 후속 검색 화면과 Repository는 생성 시 값을 고정하고 OFF에서 진입과 검색 요청을 차단한다. 실제 검색 경로와 배포별 QA 전에는 Ready로 전환하지 않는다.

## Current foundation

The app catalog in `ios/studyclub/Domain/Configuration/FeatureFlag.swift` contains Ready study.detail-api, study.list-api and study.design-system (default ON). Ready defaults ON; InProgress defaults OFF. Both Debug and Release resolve persisted overrides before stage defaults. Only Debug exposes developer settings and mutation/reset methods. Repository mode alone differs: Debug follows its saved Mock/Real selection; Release always uses Real. Feature flags never select Mock/Real.

On 2026-10-23, the user explicitly selected default ON for study.list-api and study.design-system (SC72). This rollout decision changes their stage to Ready; it is not new evidence of deployment-specific QA. Existing saved overrides remain effective until reset. Login, MyPage and My Studies remain InProgress/default OFF.

## Design-system rollout

`study.design-system` gates the sc-116 palette, card anatomy, Detail polish and light-only window as one feature. OFF uses the previous system palette/layout and OS appearance. ON uses the selected Figma green/cream design. It does not gate API requests or change Repository mode.

AppTheme creates the existing concrete DevelopmentSettingsStore and resolves the flag once per app process. This visual boundary deliberately keeps one immutable choice: a Debug toggle or Reset changes the next cold launch, not currently visible screens or a Repository-triggered root rebuild. The switch name includes the restart requirement. This avoids combining old/new palettes and layouts while the app runs, without adding a mutable global override, DI layer or theme framework. Release uses the same saved override / stage default as Debug; without an override, this Ready feature is ON. The settings UI and mutation methods remain Debug-only.

ON/OFF native comparison and an ordinary Release build cover this slice. Automatic UI and internal settings tests/scenarios are not added for the rollout; controlled render evidence must remain distinguished from installed-app flag behavior.

Feature flags select new versus previous behavior at the feature's Repository/ViewModel/View boundary, independently of Repository mode. Factory selects Debug saved Mock/Real or Release Real only. Real list OFF makes no API request and returns featureUnavailable; Main shows a distinct unavailable state. List OFF has no pagination, refresh or footer; Mock continues returning trusted Domain samples. Real detail OFF makes no API request and returns unavailable to preserve its previous failure presentation; ON calls the sc-93 API. Mock detail keeps its Domain samples. The list flag never changes detail behavior or implementation.

The `auth.google-login` definition stays InProgress (default OFF). Both Debug and Release resolve saved overrides before the stage default through the existing store. `DefaultAuthRepository` reads it at the start of each operation and again before changing credentials. OFF performs no auth request and keeps stored completed-member credentials. The flag does not choose Mock or Real. It stays InProgress until a real login, signup, restore and logout have passed. Settings reads the flag on appear and before an account action. Debug `setFlag` and `resetFlagsToDefaults` notify that screen only when `auth.google-login` changes, so an in-flight restore is invalidated without rebuilding tabs. Other flags keep their current capture behavior. A manual ON does not confirm terms: `AuthDocuments.allowsConsentAndSubmit` stays false, and onboarding then refuses consent changes and submission. The bundled terms text is unchanged and is not a legal approval.

## My Studies list · SC65

`study.my-studies` is InProgress (default OFF). SC65 registers the definition only; it adds no screen, navigation or API request. The existing development catalog, persisted overrides and reset behavior apply in both build configurations. Repository mode selection is unchanged. SC66/SC67 prepare the View and API, and SC68 owns their connection and side-effect guards. SC69 may move the same ID to Ready only after deployment-specific QA; a prepared Draft PR is not that approval. Calendar work is outside this flag's current scope.

## Add a feature

1. Add a real feature case to `FeatureFlag` and its `FeatureFlagDefinition` with a stable explicit ID, readable name and `.inProgress` stage. `CaseIterable` synthesizes the catalog; `FeatureFlag.definitions` maps it to the development rows.
2. Read configuration through the concrete `DevelopmentSettingsStore`, which owns a private standard UserDefaults value without an injection initializer. Internal development settings have no automated unit suite; do not add a protocol or factory wrapper solely for tests. Query `store.isEnabled(FeatureFlag.yourFeature.definition)` at the relevant feature boundary.
3. Guard the unfinished behavior and side effects, not only the visible entry button. Keep the existing OFF path usable. Test both ON and OFF paths before merging a small feature slice to trunk.
4. Store reads are live in both configurations. Real Repository and MainViewModel capture immutable feature values at creation; an existing screen keeps that snapshot. Specify when that feature reads its flag (screen creation, action or another explicit boundary). A settings toggle changes the next lookup; it does not automatically recreate every existing screen or cancel work.
5. After QA for the intended deployment, move the same ID from `.inProgress` (default OFF) to `.ready` (default ON), including Release. This change does not change stages. Renaming the display name or moving the stage must not change the storage ID. Existing persisted overrides remain until reset.
6. After stability is confirmed around a later deployment, remove the flag and its previous else branch together, with obsolete tests, in the same bounded change. This change does not remove flags. Do not keep completed flags indefinitely.

## Reset semantics

Reset Flag to Default removes the entire `development.featureFlags` override dictionary, including retired IDs. It then re-renders both flag sections without resetting the selected Repository mode. It never changes unrelated UserDefaults. Because defaults are not copied into storage, later stage changes take effect when no override exists.

## Verification

Internal Development Settings Store and ViewModel have no automated unit suite. The app uses only the real catalog; there are no launch-time flag fixtures. When a real flag is added or its UI changes, manually verify switches and full-row taps, app relaunch, reset preservation and landscape layout on Simulator. Manually verify that Release uses the same saved FeatureFlag overrides and stage defaults as Debug, while ignoring the saved Repository mode. Custom accessibility and large-text QA remain deferred. Use serial XCTest on the selected Simulator.

Actual feature behavior still needs its own ON/OFF tests when its case is introduced; manual settings checks do not prove an unfinished feature is ready to ship.
