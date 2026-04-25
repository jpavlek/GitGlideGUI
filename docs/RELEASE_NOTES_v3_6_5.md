# Git Glide GUI v3.6.5 Release Notes

v3.6.5 is a recovery-safety iteration. It reduces the chance that a user accidentally stages and commits unresolved conflict markers after a merge, cherry-pick, or rebase conflict.

## Changes

- Added conflict-marker scanning before **Stage resolved file**.
- Blocks staging when a complete conflict marker block is still present.
- Shows detected marker lines so the user knows what to edit.
- Keeps the existing `git add -- <file>` command plan after verification passes.
- Added tests for marker detection and formatter output.

## Validation target

Run:

```bat
cd /d scripts\windows
run-quality-checks.bat
```

Expected: static smoke passes, Windows smoke launch passes, and all Pester tests pass.
