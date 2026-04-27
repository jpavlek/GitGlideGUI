# Git Glide GUI v3.8.0 Release Notes

## Theme

Visual History & Branch Understanding.

## Branch relationship features added

- Branch relationship overview in the History / Graph area.
- Read-only ahead/behind comparison for the current branch vs its upstream, current branch vs `develop`, and `develop` vs `main`.
- Merge-base inspection to show the common ancestor used for branch relationship decisions.
- Unique commit preview using `git log --left-right --cherry-pick` before merge, pull, push, cleanup, or release decisions.

## UI polish added

- History tab now includes a dedicated branch relationship summary panel.
- Relationship summaries are mirrored into the color-coded diff/preview area for easier copying and review.
- Branch relationship command previews make the exact read-only Git commands visible before use.

## Changed

- `git-glide-gui.bat` now launches `scripts/windows/GitGlideGUI-v3.8.0.ps1`.
- Package metadata and manifest now describe the visual history and branch understanding milestone.
- Static smoke checks now require the v3.8 branch relationship markers.

## Risk managed

- The feature uses read-only Git commands only.
- Existing merge, commit, stash, tag, and recovery command semantics are intentionally preserved.
- The split-script architecture from v3.7 is retained.

## Technical-debt context

- v3.8.0 still uses versioned runtime script names. This is planned to be addressed in the follow-up v3.8.1 stabilization release by moving runtime launch paths to stable script names and treating the version as data.