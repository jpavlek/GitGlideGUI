# Git Glide GUI v3.5 Release Notes

## Focus

v3.5 continues the roadmap after the first read-only History / Graph tab by adding safer conflict/recovery guidance and first cherry-pick command planning.

## Added

- New `GitConflictRecovery.psm1` module for UI-free recovery guidance.
- New `GitCherryPickOperations.psm1` module for cherry-pick command planning.
- New **Recovery** tab with:
  - refresh recovery status,
  - abort merge,
  - continue cherry-pick,
  - abort cherry-pick,
  - cherry-pick typed commit/ref.
- Failure guidance integration for pull, merge, stash pop/apply, and cherry-pick failures.
- Temporary-repository cherry-pick workflow tests.
- Recovery classification tests for conflicts, local-overwrite risk, untracked-overwrite risk, and diverged history.

## Safety behavior

Recovery commands remain explicit. The app does not silently abort a merge or cherry-pick. Abort and continue commands are visible, previewable, and deliberately clicked by the user.

## Validation

The package includes static smoke tests, Windows smoke-launch checks, Pester tests, and optional PSScriptAnalyzer checks.
