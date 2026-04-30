# Git Glide GUI v3.10.1 Layout State Model

## Theme

v3.10.1 turns the v3.10.0 layout state model into a practical Collapsible Panel Host.

The model still remains UI-independent, but the GUI now uses it to remember whether selected workspace panels are collapsed or restored.

## What changed

- Added collapsible panel helpers to `GitLayoutState.psm1`.
- Added panel collapsed-state tests to `GitLayoutState.Tests.ps1`.
- Added Appearance-tab controls for selecting, collapsing, restoring, restoring all, and saving panel host state.
- Added non-modal shutdown behavior for layout persistence to avoid PowerShell/WinForms close-time JIT dialogs.
- Restored the nested quality-check launcher under `scripts/windows/run-quality-checks.bat`.

## Supported v3.10.1 panel hosts

```text
repositoryStatus
topWorkflow
changedFiles
diffAndOutput
diffPreview
liveOutput
```

These map to existing `SplitContainer` panels. v3.10.1 deliberately avoids a full docking rewrite.

## User workflow

1. Open Appearance.
2. Select a panel from the panel host selector.
3. Collapse or restore it.
4. Use Restore all panels when the workspace becomes too hidden.
5. Use Save panel state or Save layout now to persist the current state.

## Safety model

Collapsing a panel changes only UI layout. It does not run Git commands and does not modify repository state.

The GUI prevents both panels of the same splitter from being collapsed at once by restoring the opposite panel before collapsing the selected side.

## Shutdown behavior

v3.10.1 does not show a modal save-layout dialog from `FormClosing`.

This is intentional. PowerShell-hosted WinForms can raise `PipelineStoppedException` during shutdown if a scriptblock-backed close handler opens UI while the host pipeline is stopping.

Users can still persist layout explicitly with Save layout now or Save panel state.
