# Files Changed in v3.7.0

## Updated

- VERSION
- manifest.json
- README.md
- git-glide-gui.bat
- git-flow-gui2.bat
- scripts/windows/smoke-launch.ps1
- scripts/windows/run-quality-checks.bat
- scripts/windows/package-release.ps1
- tests/static_smoke_test.py
- docs/START_HERE.md

## Added

- scripts/windows/GitGlideGUI-v3.7.0.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part01-bootstrap-config.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part02-state-selection.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part03-previews-basic-ops.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part04-recovery-push-stash-tags.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part05-ui.ps1
- scripts/windows/GitGlideGUI-v3.7.0.part06-run.ps1
- docs/RELEASE_NOTES_v3_7.md
- docs/SWOT_AND_ROADMAP_v3_7.md
- docs/ROADMAP_REVIEW_v3_7.md
- docs/ARCHITECTURE_v3_7.md
- docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_7.md
- docs/FILES_CHANGED_v3_7.md

## Removed from release package

- scripts/windows/GitGlideGUI-v3.6.13.ps1

The old implementation is not included in the v3.7 package to avoid version drift and to enforce the split-script architecture.
