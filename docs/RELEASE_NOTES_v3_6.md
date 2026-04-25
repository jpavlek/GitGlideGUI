# Git Glide GUI v3.6.1 Release Notes

## Focus

v3.6 improves conflict recovery and graph-action coupling while fixing two v3.5 quality issues.

## Added

- Resolved/unresolved conflict-state detection from `git status --porcelain`, `git diff --name-only --diff-filter=U`, and Git state markers.
- Stage selected resolved conflict file from the Recovery tab.
- Continue interrupted operation guidance for merge, cherry-pick, and rebase.
- External merge tool command configuration and launch action.
- Improved History / Graph selection and command preview coupling.

## Fixed

- Closing the initial repository-choice dialog with X now aborts startup instead of behaving like Continue without repo.
- Untracked-file overwrite output is classified before generic local-changes overwrite output.
- Cherry-pick conflict workflow test captures expected Git failure output without letting stderr stop the test script.

## Validation

Static smoke validation and ZIP integrity validation were performed in the build environment. Windows PowerShell / WinForms / Pester checks should be run with:

```bat
run-quality-checks.bat
```
