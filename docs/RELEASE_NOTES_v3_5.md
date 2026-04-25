# Git Glide GUI v3.5 Release Notes

## Focus

v3.5 improves conflict recovery, history-driven cherry-picking, visual history inspection, and beginner learning guidance.

## Added

- Recovery tab now includes a conflict-file list powered by:
  - `git diff --name-only --diff-filter=U`
- Added actions for conflicted files:
  - Open selected file
  - Open selected folder
  - Double-click conflicted file to open it
- History / Graph tab now includes a first simple visual graph/list model:
  - Kind: commit or merge
  - Short hash
  - Parent hashes
  - Decorations / refs
  - Subject
  - Author
- Added `Use selected for cherry-pick` workflow from History / Graph into Recovery.
- Added Learning tab explaining:
  - what common Git commands mean
  - what they do
  - when they are useful
  - typical software-development Git workflows

## New module

- `modules/GitGlideGUI.Core/GitLearningGuidance.psm1`

## Extended modules

- `GitConflictRecovery.psm1`
  - conflict file list parsing
  - conflict file guidance formatting
- `GitHistoryOperations.psm1`
  - visual graph/list row formatting

## Tests

Added/extended tests for:

- learning guidance
- conflict-file list parsing
- conflict-file guidance formatting
- visual history/list rows

## Notes

The visual graph is intentionally simple and read-only. It is a safe intermediate step before a richer branch graph control.
