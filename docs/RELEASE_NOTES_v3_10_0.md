# Git Glide GUI v3.10.0 Release Notes

## Focus

Modular Layout State Model and explicit layout save policy.

## Added

- `modules/GitGlideGUI.Core/GitLayoutState.psm1`
- `tests/GitLayoutState.Tests.ps1`
- `docs/LAYOUT_STATE_MODEL_v3_10_0.md`
- UI-independent layout state model for future panel hosts
- Appearance tab controls for layout save/discard/reset
- Save policy selector: `ask-on-exit`, `always`, `never`

## Changed

- `VERSION` and `manifest.json` now report v3.10.0.
- Layout persistence now stores both legacy splitter values and a structured `LayoutState` object.
- Form closing uses the configured save policy instead of always saving layout silently.

## Validation

Run:

```bat
python -S tests\static_smoke_test.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
scripts\windows\run-quality-checks.bat
```

## Notes

v3.10.0 intentionally does not add full docking yet. It prepares the architecture for collapsible, stackable, and dockable panels without destabilizing the current WinForms UI.
