# Git Glide GUI v3.10.0 Changed Files

## Added files

- `docs/ARCHITECTURE_v3_10_0.md`
- `docs/FILES_CHANGED_v3_10_0.md`
- `docs/LAYOUT_STATE_MODEL_v3_10_0.md`
- `docs/RELEASE_NOTES_v3_10_0.md`
- `docs/ROADMAP_REVIEW_v3_10_0.md`
- `docs/SWOT_AND_ROADMAP_v3_10_0.md`
- `docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_10_0.md`
- `metrics/snapshots/gitglide_metrics_v3_10_0.json`
- `modules/GitGlideGUI.Core/GitLayoutState.psm1`
- `tests/GitLayoutState.Tests.ps1`

## Modified files

- `VERSION`
- `manifest.json`
- `README.md`
- `docs/START_HERE.md`
- `metrics/METRICS_REPORT.md`
- `metrics/feature_manifest.json`
- `metrics/snapshots/gitglide_metrics_latest.json`
- `scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1`
- `scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1`
- `scripts/windows/GitGlideGUI.part05-ui.ps1`
- `tests/static_smoke_test.py`

## Removed files

- None.

## Validation performed in this package build

- `python -S tests/static_smoke_test.py` passed in the build workspace.
- Metrics snapshot and Markdown report were regenerated for v3.10.0.

## Notes

PowerShell/Pester validation should still be run on Windows with:

```bat
scripts\windows\run-quality-checks.bat
```
