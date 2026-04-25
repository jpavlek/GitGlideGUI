# Git Glide GUI v3.2 - Commit Operations Extraction

## Summary

Git Glide GUI v3.2 continues the roadmap-driven modularization work. It extracts commit planning and validation into a UI-free module, adds temporary-repository commit workflow tests, improves commit-message guidance, and prepares a compact history model for the future visual commit graph.

## Added

- `modules/GitGlideGUI.Core/GitCommitOperations.psm1`
  - commit message building
  - commit subject validation
  - optional Conventional Commits guidance
  - normal commit command planning
  - initial commit command planning
  - amend and push preview planning
  - soft undo-last-commit planning
  - compact commit/history model command planning
  - compact commit log line parser for future graph work

- `tests/GitCommitOperations.Tests.ps1`
- `tests/GitRepositoryCommitWorkflow.Tests.ps1`
- root-level convenience wrappers:
  - `run-quality-checks.bat`
  - `run-pester-tests.bat`
- `scripts/windows/run-pester-tests.bat`

## Improved

- Commit preview now uses extracted module logic when available.
- Added optional **Conventional guidance** checkbox in the commit panel.
- Commit preview now includes warnings/guidance when the subject is empty, long, has a final period, or does not match optional Conventional Commits style.
- Undo-last-commit preview now uses the extracted commit module plan when available.
- Pester runner now sanitizes invalid process-level `LIB`, `INCLUDE`, and `LIBPATH` entries before importing Pester. This addresses environments where stale paths such as `D:\GTK\LIB` can cause Pester 3.x import to fail through PowerShell `Add-Type`.
- Added root-level wrappers so users can run quality checks from the extracted package root without remembering the scripts subfolder.

## Quality gate

Release packaging still requires the Windows smoke-launch check before packaging. This keeps parser/import regressions from being released.

## Known limitation

Live WinForms testing still requires Windows. Static validation and ZIP integrity checks can be performed in the artifact environment, but the GUI must be opened on Windows 10/11 for final validation.
