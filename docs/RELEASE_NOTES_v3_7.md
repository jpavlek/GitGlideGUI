# Git Glide GUI v3.7.0 Release Notes

## Theme

Branch Sync & Conflict Recovery UX plus technical-debt reduction.

## Added

- Repository State Doctor for detached HEAD, divergence, in-progress recovery operations, unmerged files, and conflict markers.
- Conflict marker scanner for changed and unmerged files.
- Split-script GUI architecture: one stable versioned entrypoint plus six ordered implementation parts.
- GUI validation button now validates the split script set instead of only one monolithic file.
- Dynamic Changed Files context banner sizing.
- Static smoke-test line-count guard to prevent another 8k+ line version file.

## Changed

- `git-glide-gui.bat` now launches `scripts/windows/GitGlideGUI-v3.7.0.ps1`.
- `smoke-launch.ps1` validates the split entrypoint with `-SmokeTest`.
- `run-quality-checks.bat` runs Python static checks with `python -S` and `PYTHONNOUSERSITE=1` to reduce environment noise.
- Package metadata and manifest now describe the split-script architecture.

## Risk management

The refactor intentionally does not rewrite existing Git operation semantics. The first step is structural: preserve behavior while reducing file size, merge-conflict risk, and version-copy drift.
