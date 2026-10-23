# iOS Simulator test storage

Read this file when running XCTest on Simulator. General test scope stays in [Testing](TESTING.md).

- Run XCTest serially by default with `-parallel-testing-enabled NO`. For XcodeBuildMCP `test_sim`, pass `extraArgs: ["-parallel-testing-enabled", "NO"]` or set that session's default before testing. Session defaults are process-local.
- Reuse the selected named CoreSimulator device. Parallel testing may create isolated XCTest worker clones even when a base destination is selected.
- Enable parallel testing only when the task needs it. Cap it with `-maximum-parallel-testing-workers 2`, then inspect `~/Library/Developer/XCTestDevices` after Xcode and XCTest exit.
- Never remove Simulator or XCTest device data while Xcode, `xcodebuild`, `xctest`, or Simulator is active. Treat deletion as separately approved cleanup with an age threshold and before/after disk checks.
- XcodeBuildMCP protected purge covers its managed logs, result bundles, test products, and DerivedData; it does not clean `~/Library/Developer/XCTestDevices`.
- Reuse a stable build destination where supported. Retain only the small logs, result summaries, and captures needed for handoff. Test products and DerivedData can be rebuilt.
- At the end of XcodeBuildMCP work, check retained artifacts and their disk use. Automatic lifecycle cleanup covers only the active managed workspace and does not purge DerivedData.
- For task-created artifacts or previously approved old artifacts, run the installed tool's `purge --report` and `purge --dry-run` with exact workspace, classes, and age before `purge --delete` with its required confirmation token. Check active build/test processes, open paths, workspace locks, and protected candidates first. Select DerivedData only when no build uses it. Save the deletion receipt and verify final paths and disk readings.
- For the approved old XcodeBuildMCP workspaces, use `~/.codex/scripts/xcodebuildmcp-retention.py`. Read its receipt. A skipped cleanup does not prove storage was reclaimed.
- Preserve recent, active, pinned, and unrelated preexisting artifacts. For out-of-scope data, report its size and owner instead of deleting it. MCP purge never authorizes Simulator or XCTest device cleanup.
