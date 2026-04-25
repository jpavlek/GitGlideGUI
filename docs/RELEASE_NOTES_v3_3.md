# Git Glide GUI v3.5 Release Notes

## Focus

v3.5 adds the first read-only History / Graph workflow while preserving the stability work from v3.2.x.

## Added

- New `History / Graph` tab.
- Read-only graph display powered by `git log --graph --decorate --oneline --all`.
- Max-commit selector for large repositories.
- History summary action that parses compact commit records and reports commit, merge, and decorated-ref counts.
- New module: `modules/GitGlideGUI.Core/GitHistoryOperations.psm1`.
- New tests:
  - `tests/GitHistoryOperations.Tests.ps1`
  - `tests/GitRepositoryHistoryWorkflow.Tests.ps1`

## Fixed

- Fixed the last known Pester 3 compatibility failure from v3.2.4 by changing the tag-delete workflow test from invalid `$exists@().Count` syntax to `@($exists).Count`.

## Notes

The History / Graph tab is intentionally read-only. It is meant to help users inspect branch shape, tags, and merge commits before switching, pulling, merging, deleting tags, or undoing commits.
