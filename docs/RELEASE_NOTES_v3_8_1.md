# Git Glide GUI v3.8.1 Release Notes

## Theme

Version source-of-truth, stable runtime filenames, and release-churn reduction.

## Stabilization added

- Stable runtime entrypoint: `scripts/windows/GitGlideGUI.ps1`.
- Stable split script filenames under `scripts/windows/`.
- Runtime version lookup through `VERSION` instead of hardcoded versioned script names.
- Launcher and smoke-launch scripts now target the stable entrypoint.
- Static smoke checks now validate stable script names and continue guarding split-script size and merge-conflict markers.

## Changed

- `git-glide-gui.bat` no longer needs a version bump for every release.
- `manifest.json` now points to the stable main script and stable split script parts.
- GUI script validation validates the stable split script set.
- `package-release.ps1` and `init-gitglide-repo.ps1` can derive the version from `VERSION` when no explicit version is provided.

## Risk managed and technical debt reduced

- Existing Git operation semantics were intentionally preserved.
- This release reduces future file churn, merge-conflict risk, and review noise caused by version-only runtime script renames.
- Future releases can update `VERSION`, release docs, and functional changes without renaming the GUI implementation files.
