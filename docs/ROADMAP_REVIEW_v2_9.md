# Git Glide GUI Roadmap Review after v2.9

## Implemented so far

### Product identity and onboarding

- Renamed product to Git Glide GUI.
- Kept backward-compatible `git-flow-gui2.bat` launcher.
- Added intention-based startup choices:
  - Open existing repo
  - Init new repo
  - Continue without repo
- Added repository picker and new-repository initialization.
- Added first-commit wizard.
- Added `.gitignore` templates.
- Added remote setup workflow.

### Safety and trust

- Added command safety module.
- Added stricter custom Git command validation.
- Added destructive command confirmations.
- Added audit logging.
- Added soft undo last commit.
- Added safe startup handling outside a repository.
- Added dirty-working-tree guidance before branch switch, pull, and merge.

### Git workflows

- Added stash command UX.
- Added tag/release management.
- Added branch action improvements.
- Added fast-forward-only pull planning for branch workflows.
- Added suggested next action panel and safe action execution for selected states.

### Modularization completed so far

- `GitCommandSafety.psm1`
- `GitRepositoryStatus.psm1`
- `GitRepositoryOnboarding.psm1`
- `GitStagingOperations.psm1`
- `GitBranchOperations.psm1`

### Tests added so far

- Command safety tests.
- Repository status tests.
- Repository initialization tests.
- Repository onboarding tests.
- Staging helper and temporary-repository staging tests.
- Branch helper and temporary-repository branch workflow tests.
- Static package smoke test.

## Still to do

### Short-term

- Extract stash operations into `GitStashOperations.psm1`.
- Extract tag/release operations into `GitTagOperations.psm1`.
- Add Windows GUI smoke launch test.
- Add PSScriptAnalyzer baseline and CI-ready quality check.
- Improve Suggested Next Action for stash and conflict recovery.

### Medium-term

- Visual commit/branch graph.
- Cherry-pick workflow.
- Interactive rebase helper.
- Reflog-based recovery UI.
- File history/blame view.
- Worktree support.

### Long-term

- GitHub/GitLab PR integration.
- CI/CD status integration.
- Accessibility pass.
- Cross-platform strategy if adoption justifies the investment.

## Implemented outside the original roadmap

These were not originally prioritized highly enough, but real feedback showed they were important:

- Product rename and compatibility transition.
- Open/init/continue startup intent handling.
- New-repository onboarding.
- First-commit wizard.
- `.gitignore` template flow.
- Remote setup flow.
- Beginner/Advanced mode.
- Startup dialog hotfixes from live user testing.

## Does the roadmap need revising?

Only slightly. The strategic direction remains correct, but the near-term roadmap should explicitly keep onboarding, safe suggestions, and small module extraction ahead of large visual features.

Recommended next order:

1. Continue extracting workflow modules.
2. Add tests for each extracted workflow.
3. Add Windows smoke launch testing.
4. Then implement visual graph and conflict-resolution features with less regression risk.
