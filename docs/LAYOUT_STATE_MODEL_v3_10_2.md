# Git Glide GUI v3.10.2 Layout State Model

## Theme

Canonical panel registry and layout-host consistency.

v3.10.2 keeps the v3.10.1 Collapsible Panel Host, but removes ambiguity between the GUI adapter panel IDs and the UI-independent Layout State Model.

## Canonical panel registry

`GitLayoutState.psm1` now exposes:

```text
Get-GglsCanonicalPanelRegistry
Get-GglsCanonicalPanelId
```

The canonical registry includes the panel IDs used by the GUI adapter:

```text
repositoryStatus
topWorkflow
workflowActions
commitPreview
changedFiles
diffAndOutput
diffPreview
liveOutput
appearanceEditor
```

The collapsible WinForms panel host currently exposes this practical subset:

```text
repositoryStatus
topWorkflow
changedFiles
diffAndOutput
diffPreview
liveOutput
```

## Legacy compatibility

v3.10.1 used `commandOutput` in parts of the core model and `liveOutput` in the GUI adapter. v3.10.2 treats `commandOutput` as a legacy alias and normalizes it to `liveOutput`.

This preserves old layout state while avoiding a parallel vocabulary going forward.

## Save policy

The visible policies are now:

```text
manual
always
never
```

`ask-on-exit` remains accepted as a legacy value, but it is normalized to `manual`.

This is intentional because the application no longer shows modal prompts from `FormClosing`. Users can explicitly persist layout with Save layout now or Save panel state.

## Safety model

Collapsing a panel changes only UI layout. It does not run Git commands and does not modify repository state.

The GUI adapter prevents both panels of the same splitter from being collapsed at once by restoring the opposite panel before collapsing the selected side.
