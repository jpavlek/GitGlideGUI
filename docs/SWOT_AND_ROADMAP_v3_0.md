# Git Glide GUI v3.0 SWOT and Roadmap

## SWOT snapshot

### Strengths

- Better product identity after the rename from Git Flow GUI to Git Glide GUI.
- Safer onboarding: open existing repo, init new repo, continue without repo.
- Improved engineering foundation through extracted modules for command safety, repository status, onboarding, staging, branch operations, and stash operations.
- More workflow guidance through Suggested Next Action and Beginner mode.
- Better recovery behavior after stash apply/pop failures.

### Weaknesses

- Main WinForms script is still large and monolithic.
- Live GUI testing is still manual unless run on Windows.
- No visual commit graph yet.
- No visual merge-conflict resolver yet.
- Pester/ScriptAnalyzer are optional and depend on the user environment.

### Opportunities

- Continue extracting modules while keeping the GUI functional.
- Add visual graph and conflict-resolution UI once core command planning is tested.
- Add GitHub/GitLab PR workflows after branch/stash/tag services are stable.
- Add AI-assisted guidance later, using the structured status/action modules as input.

### Threats

- Regression risk remains while the main script is large.
- Git edge cases vary across Git versions and repository states.
- Competing tools already provide graph, conflict, and PR integrations.
- Users may lose trust quickly if startup/parser regressions reappear.

## Roadmap priority after v3.0

### v3.1 recommended

1. Extract tag/release operations into `GitTagOperations.psm1`.
2. Add temporary-repository tests for annotated tags, lightweight tags, push-preview planning, and local delete safety.
3. Add a Windows parser smoke test to the ZIP validation checklist before every release.
4. Improve dirty-tree checks around tag/release operations where relevant.

### v3.2 recommended

1. Extract commit operations into `GitCommitOperations.psm1`.
2. Add commit-message validation and conventional-commit optional helper.
3. Add tests for commit, amend, undo last commit, and commit+push previews.

### v3.5 recommended

1. Add minimal visual commit/branch graph.
2. Keep it read-only first.
3. Use existing repository-status and branch modules as data inputs.

### v3.5 recommended

1. Add merge-conflict guidance UI.
2. Start with conflict detection and file list, then add visual resolution later.
