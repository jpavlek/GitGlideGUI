# Git Glide GUI v3.10.1 Architecture

## Theme

Collapsible panel hosts on top of the modular layout state model.

v3.10.1 keeps the same architecture boundary as v3.10.0: core layout state stays UI-free, while WinForms control mapping stays in the GUI adapter layer.

## Core module

```text
modules/GitGlideGUI.Core/GitLayoutState.psm1
```

The module owns:

- default layout state
- panel state lookup
- panel collapsed-state mutation
- panel last-size metadata
- save policy normalization
- layout summary formatting
- collapsible panel host summary formatting

## GUI adapter responsibilities

The GUI owns:

- mapping panel IDs to concrete `SplitContainer` controls
- preventing both sides of the same splitter from being collapsed
- updating WinForms `Panel1Collapsed` and `Panel2Collapsed`
- refreshing the Appearance-tab panel selector
- saving updated panel state into config

## Safety boundary

The layout state module does not know about WinForms and does not mutate controls.

The GUI adapter does not invent layout semantics. It maps concrete controls to the model.

## Risk control

v3.10.1 avoids a full docking rewrite. It only adds collapse/restore behavior to known split containers.

## Shutdown architecture

Close-time layout persistence is non-modal. This avoids PowerShell/WinForms shutdown exceptions and keeps save behavior explicit through Save layout now / Save panel state.

## Next architecture step

v3.10.2 should introduce Stackable Workspace Groups, still using the same layout-state model rather than creating unrelated UI state.
