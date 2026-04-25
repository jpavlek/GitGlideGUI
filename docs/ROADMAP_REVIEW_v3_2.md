# Git Glide GUI Roadmap Review after v3.2

## Implemented from the roadmap

- Security hardening and safer custom commands.
- Audit logging.
- Soft undo last commit.
- Tag/release management.
- Repository detection, open existing repository, and initialize new repository.
- First commit wizard, `.gitignore` templates, and remote setup.
- Suggested Next Action panel with safe executable actions.
- Beginner / Advanced mode.
- Static smoke tests, Pester-style module tests, and temporary Git repository workflow tests.
- Windows smoke-launch parser/import test.
- Mandatory packaging gate that requires smoke-launch before release packaging.
- Module extraction started and continued through:
  - `GitCommandSafety.psm1`
  - `GitRepositoryStatus.psm1`
  - `GitRepositoryOnboarding.psm1`
  - `GitStagingOperations.psm1`
  - `GitBranchOperations.psm1`
  - `GitStashOperations.psm1`
  - `GitTagOperations.psm1`
  - `GitCommitOperations.psm1`

## Implemented outside the original roadmap but justified by product feedback

- Renamed the project from Git Flow GUI to Git Glide GUI.
- Added backward-compatible launcher transition.
- Added startup intent choices: Open existing repo, Init new repo, Continue without repo.
- Fixed the extracted-tool-folder launch case.
- Added first-commit onboarding and repository initialization workflows.
- Added Pester environment sanitization for invalid `LIB`/`INCLUDE`/`LIBPATH` paths.
- Added root-level quality-check wrappers for easier user execution.

## Still to do

- Visual commit / branch graph.
- Visual merge conflict resolution.
- Interactive rebase helper.
- Cherry-pick workflow.
- Reflog-based recovery UI.
- File history / blame view.
- Worktree support.
- GitHub / GitLab PR integration.
- CI quality pipeline on Windows.
- Larger accessibility pass.

## Does the roadmap need revising?

Yes, but only moderately.

The original roadmap correctly identified security, testing, modularization, graph visualization, and conflict resolution as important. Real user feedback showed that repository-intent handling, onboarding, startup UX, test-running ergonomics, and environment robustness had to move earlier.

The revised short-term roadmap should be:

1. Finish extraction of core Git operations.
2. Keep mandatory smoke-launch and package quality gates.
3. Build the first read-only history/graph feature from the new commit/history model.
4. Then move into conflict resolution, cherry-pick, and rebase workflows.
