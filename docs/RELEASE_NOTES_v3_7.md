# Git Glide GUI v3.7.0 Release Notes

## Theme

Branch Sync & Conflict Recovery UX, color-coded diff visibility, and technical-debt reduction.

## Branch sync and recovery features added

- Repository State Doctor for detached HEAD, branch divergence, in-progress recovery operations, unmerged files, and conflict marker risks.
- Conflict marker scanner for changed and unmerged files.
- GUI validation button now validates the split script set instead of only one monolithic file.

## UI polish added

- Color-coded RichTextBox diff preview for added, removed, hunk, metadata, warning, error, and conflict-marker lines.
- Configurable diff-preview colors through the existing Appearance color catalog.
- Dynamic Changed Files context banner sizing.
- Git status, graph/history output, stash diffs, selected-file diffs, and custom-command output now route through the same centralized diff-preview renderer.

## Changed

- `git-glide-gui.bat` now launches `scripts/windows/GitGlideGUI-v3.7.0.ps1`.
- `smoke-launch.ps1` now derives the target GUI script from `VERSION` and validates the split entrypoint with `-SmokeTest`.
- `run-quality-checks.bat` runs Python static checks with `python -S` and `PYTHONNOUSERSITE=1` to reduce environment noise.
- Package metadata and manifest now describe the split-script architecture.

## Risk managed and technical debt reduced

- Split-script GUI architecture: one stable versioned entrypoint plus six ordered implementation parts.
- Static smoke-test line-count guard to prevent another 8k+ line version file.
- Existing Git operation semantics were intentionally preserved. This release reduces file size, merge-conflict risk, and version-copy drift without rewriting the core Git behavior.
