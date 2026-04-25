# Git Glide GUI Roadmap Review v3.5

## Implemented in this iteration

- First read-only History / Graph tab.
- Extracted history operations into `GitHistoryOperations.psm1`.
- Added parser for compact commit log records.
- Added merge-commit parsing tests.
- Added temporary-repository history workflow tests.
- Fixed the final known Pester 3 syntax issue from v3.2.4.

## Roadmap status

Completed from the immediate roadmap:

- Modular extraction for command safety, repository status, onboarding, staging, branch, stash, tag, commit, and history workflows.
- Temporary-repository tests for several core workflows.
- Mandatory smoke-launch quality gate.
- First read-only history/graph feature.

Still pending:

- True visual graph control.
- Conflict-resolution workflow.
- Cherry-pick workflow.
- Reflog recovery UI.
- Worktree support.
- File history / blame.
- GitHub/GitLab pull-request integration.

## Roadmap revision

The roadmap remains valid. The practical short-term priority should now move from pure extraction toward user-visible Git recovery workflows. Conflict guidance and cherry-pick are more valuable next than immediately building a complex visual graph control.
