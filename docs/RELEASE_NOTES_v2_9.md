# Git Glide GUI v2.9 Release Notes

## Focus

v2.9 continues the roadmap priority of low-risk modularization plus practical UX safety. It extracts branch workflow planning into a UI-free module, adds branch workflow tests, improves dirty-working-tree guidance before branch operations, and makes more Suggested Next Action states safely executable.

## Added

- New branch module:
  - `modules/GitGlideGUI.Core/GitBranchOperations.psm1`
- New tests:
  - `tests/GitBranchOperations.Tests.ps1`
  - `tests/GitRepositoryBranchWorkflow.Tests.ps1`
- New Branch tab action:
  - `Pull current branch`
- New Suggested Next Action executable cases:
  - ahead branch -> confirm and push current branch
  - behind branch -> confirm and pull current branch with `--ff-only`

## Improved

- Branch command previews now use the extracted branch module when available.
- Pulls used by feature-branch creation and merge flows now prefer `git pull --ff-only` to avoid surprise merge commits.
- Working-tree safety checks now explain the risk more clearly before switching, pulling, or merging:
  - staged count
  - unstaged count
  - untracked count
  - conflicted count when present
- Merge flows now use generated branch command plans when the branch module is available.

## Fixed / reduced risk

- Dirty-tree guidance is now operation-aware instead of using a generic warning only.
- Suggested actions now route through confirmation dialogs for remote-affecting actions such as push and pull.

## Validation

Static package validation passed in the artifact build environment. Live WinForms GUI execution still needs Windows PowerShell on Windows 10/11.
