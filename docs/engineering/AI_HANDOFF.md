# AI Work Handoff

Use this contract when an AI-assisted task changes the repository. Keep it short, factual, and reproducible.

For issue-based work, include the Notion issue number and URL, and any existing PR link. Follow the commit/PR issue-number prefix in [Engineering Conventions](CONVENTIONS.md). Do not invent a missing issue or PR number.

## Required handoff

1. **Outcome** — what now works, in user-facing terms.
2. **Scope** — files or modules changed and important non-goals.
3. **Architecture decisions** — any dependency, state, navigation, concurrency, or naming decision introduced or preserved.
4. **Verification** — exact build/test command or tool, result counts, and relevant Simulator scenarios.
5. **Evidence** — paths to logs, result bundles, or visual captures when they exist.
6. **Repository state** — branch plus whether work is unstaged, staged, committed, or pushed.
7. **Open gates** — external facts still needed, such as API URL, auth, schema, signing, or product copy.

## Evidence rules

- Do not describe a build as tested unless a fresh test result exists for the same source state.
- Separate mock behavior from live API or production behavior.
- Separate source/configuration checks from Simulator observation and release readiness.
- Never place secrets, personal data, machine credentials, or copied server payloads in a handoff.
- Link to repository files and durable evidence instead of pasting large logs.

## Minimal template

```text
Notion issue / PR:
Outcome:
Scope / non-goals:
Architecture decisions:
Verification:
Evidence:
Repository state:
Open gates:
```
