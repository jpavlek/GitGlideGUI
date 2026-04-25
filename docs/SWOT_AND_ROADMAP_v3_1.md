# Git Glide GUI v3.1 SWOT and Roadmap Update

## SWOT snapshot

### Strengths

- Lightweight Windows Git workflow GUI.
- Git command previews remain central to user trust.
- Safety-first direction is clearer after audit logging, guarded custom commands, soft undo, repository onboarding, branch guidance, stash guidance, and tag command planning.
- Modular extraction is now visible across command safety, repository status, onboarding, staging, branches, stashes, and tags.

### Weaknesses

- Main WinForms script is still monolithic.
- Visual branch graph and visual conflict resolution are still missing.
- Some tests require Windows, PowerShell, Git, and optionally Pester.
- Packaging validation is stronger, but full CI/CD is still not present.

### Opportunities

- Continue module extraction until most Git operations are testable without the UI.
- Add visual graph after status/branch/commit logic is extracted.
- Add commit-operation extraction next to prepare for commit templates, amend safety, and history tooling.
- Build a release workflow around the new mandatory package gate.

### Threats

- Small parser regressions can still break startup if packaging gates are bypassed.
- Existing mature tools already offer graph and conflict UX.
- Windows-only WinForms limits audience until a later platform strategy is chosen.

## Roadmap position after v3.1

v3.1 completes another architecture-evolution step from the original roadmap: core Git operations are gradually becoming UI-free modules with temporary-repository tests.

Completed module extractions:

```text
GitCommandSafety.psm1
GitRepositoryStatus.psm1
GitRepositoryOnboarding.psm1
GitStagingOperations.psm1
GitBranchOperations.psm1
GitStashOperations.psm1
GitTagOperations.psm1
```

## Recommended v3.2

```text
1. Extract commit operations into GitCommitOperations.psm1.
2. Add temporary-repository tests for initial commit, normal commit, commit+push preview, amend preview, and soft undo planning.
3. Improve commit-message validation and optional conventional-commit guidance.
4. Prepare the first minimal commit/history model for the visual graph.
```

## Recommended v3.5

```text
1. Add a first read-only visual commit graph or graph text panel.
2. Use extracted status/branch/tag/commit services as data sources.
3. Keep graph interaction minimal at first: select commit, copy hash, inspect details.
```
