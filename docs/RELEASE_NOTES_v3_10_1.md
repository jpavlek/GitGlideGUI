# Git Glide GUI v3.10.1 Release Notes

## Focus

v3.10.1 adds the Collapsible Panel Host on top of the v3.10.0 modular layout state model.

## Added

- Collapsible panel state helpers in `GitLayoutState.psm1`.
- Tests for collapsing, restoring, and preserving panel size metadata.
- Appearance-tab controls for selecting a panel, collapsing it, restoring it, restoring all panels, and saving panel state.
- Static smoke markers for collapsible panel host integration.
- v3.10.1 layout state, architecture, roadmap, SWOT, and technical-debt documentation.

## Fixed

- Restored `scripts/windows/run-quality-checks.bat`, which was empty in the v3.9.1/v3.10.0 package line.
- Removed modal layout-save prompting from the close path to avoid `PipelineStoppedException` / JIT debugging dialogs during shutdown.

## Validation target

- Static smoke test passes.
- Smoke launch parses split scripts.
- Pester covers layout state helpers.
- Quality checks run through the restored nested launcher.
