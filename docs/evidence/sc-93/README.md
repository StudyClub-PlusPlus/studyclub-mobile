# SC-93 Simulator Evidence

Historical evidence from sc-93 before the sc-145 rebase. The commands, test counts and images below describe that earlier source only; UI tests and launch scenarios have since been removed. These captures are not current QA for sc-145.
- Captured: 2026-09-20
- Device: iPhone 17 Pro Simulator
- Runtime: iOS 26.2
- Source: `boa/sc-93`
- Data: deterministic Mock scenarios used by UI tests

## Screens

- `main-content.png`: study list content before navigation
- `detail-content.png`: selected study detail content
- `detail-loading.png`: detail loading state
- `detail-failure.png`: detail failure state without retry
- `detail-empty.png`: missing study state with “스터디를 찾을 수 없어요”

## Verification

```bash
xcodebuild test \
  -project ios/studyclub.xcodeproj \
  -scheme studyclub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:studyclubUITests/StudyClubFlowUITests/testContentOpensTheSelectedStudyDetail \
  -only-testing:studyclubUITests/StudyClubFlowUITests/testDetailFailureAllowsBackNavigationWithoutRetry \
  -only-testing:studyclubUITests/StudyClubFlowUITests/testDetailLoadingAndBackNavigation \
  -parallel-testing-enabled NO
```

All three UI tests passed. These captures verify UI states with Mock data; they are not evidence of a successful Stage API request.
