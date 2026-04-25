# Git Glide GUI Roadmap Review v3.5

## Implemented in v3.5

- Conflict/recovery guidance module.
- Recovery panel in the GUI.
- Failure guidance for pull, merge, stash apply/pop, and cherry-pick failures.
- Cherry-pick command planning and guarded execution.
- Tests for recovery classification and cherry-pick workflows.

## Roadmap items advanced

- Core Git workflows now have module coverage for command safety, repository status, onboarding, staging, branch, stash, tag, commit, history, recovery, and cherry-pick operations.
- The History / Graph tab is now paired with Recovery, making future visual graph work more useful.

## Still pending

- True visual graph control.
- Rich conflict-resolution UI.
- File history / blame view.
- GitHub/GitLab PR integration.
- Worktree/submodule/LFS workflows.
- Cross-platform implementation.

## Roadmap adjustment

The roadmap remains directionally correct. The practical next step should not be a full visual graph rewrite yet. The Recovery tab should first get conflict-file awareness and open-file actions, because that gives immediate value when Git operations fail.
