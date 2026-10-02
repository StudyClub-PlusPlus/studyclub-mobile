# SC-93 public detail API verification

- Verified: 2026-10-03 (Asia/Seoul)
- Issue: [#93](https://app.notion.com/p/benkang/3df83feabad380b78cabc8be96f79990)
- PR: https://github.com/StudyClub-PlusPlus/studyclub-mobile/pull/1
- Reference: studyclub-engineering backend StudyController, StudyDetailResponse, StudyCategory, StudyStatus and public Production responses.
- Production: https://api.studyclub-plusplus.com/api/
- Stage DNS still does not resolve; the client explicitly uses Production by default and does not silently retry across environments.

## Scope

Detail accepts the current 11 categories, 5 lifecycle statuses and nullable recruitStatus. Presentation owns category display labels and omits absent recruitment text without a trailing separator. Detail flag is Ready/default ON; explicit OFF retains Mock. Repository mode retains its existing Mock default. DTOs remain in Data; Repository returns Domain models. List integration is excluded, so normal Real list-to-detail navigation remains a separate task.

## Verification

```sh
TEST_RUNNER_STUDYCLUB_LIVE_API_BASE_URL=https://api.studyclub-plusplus.com/api/ xcodebuild test \
  -project ios/studyclub.xcodeproj -scheme studyclub \
  -destination 'platform=iOS Simulator,id=A893B811-CF88-4164-BE91-22911A424235' \
  -only-testing:studyclubTests \
  -only-testing:studyclubUITests/StudyClubFlowUITests/testContentOpensTheSelectedStudyDetail \
  -parallel-testing-enabled NO -derivedDataPath /tmp/sc93-review-build
```

48 unit tests passed, including 4 opt-in live checks. Mock list-to-detail UI test passed. Live checks call public details 18 and 87, assert missing detail 999999 returns notFound, and load/render DetailViewController after a live request. These tests skip by default without the opt-in environment variable; normal unit tests do not depend on server availability.

`live-detail-content.png` is a rendered DetailViewController view from the Simulator unit test with live API content. It is not a full navigation screenshot or evidence of live list integration. Visual inspection confirmed the category, title, metadata and description render without clipping. Result bundle: /tmp/sc93-review-build/Logs/Test/Test-studyclub-2026.10.03_01-00-03-+0900.xcresult. Logs: /tmp/sc93-live-tests.log.

Repository state after completion: boa/sc-93, committed and pushed to the existing PR. Backend and list API code are unchanged. Remaining external checks: Stage DNS and future list integration; saved Debug OFF overrides must be reset/enabled when testing Real detail.

Release build also passed:

```sh
xcodebuild build -project ios/studyclub.xcodeproj -scheme studyclub \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/sc93-review-build
```

Release log: /tmp/sc93-live-release.log. `git diff --check` passed.
