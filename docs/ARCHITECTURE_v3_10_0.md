# Git Glide GUI v3.10.0 Architecture

## Theme

Modular layout state with minimal UI risk.

v3.10.0 introduces a layout model independent of WinForms controls. Existing splitters still work, but the application now has a structured representation of layout intent.

## New module

```text
modules/GitGlideGUI.Core/GitLayoutState.psm1
```

## Module responsibilities

`GitLayoutState.psm1` owns:

- default layout state creation
- layout save policy normalization
- panel state lookup
- panel state updates
- splitter-distance import into layout state
- layout summary formatting

## GUI responsibilities

The GUI owns:

- mapping WinForms controls to layout panel IDs
- applying safe splitter distances
- asking whether to save layout on exit
- rendering Appearance-tab layout controls
- saving layout state to `GitGlideGUI-Config.json`

## Safety boundary

The core module contains no WinForms dependency and does not mutate the repository.

The GUI decides when to save, discard, reset, and apply the layout state.

## Command-plan continuity

This is not a Git command feature, but it follows the same product principle:

```text
state as data
  -> visible summary
    -> explicit user choice
      -> save/discard/reset
```

## Architecture risk

`part05-ui.ps1` still contains too much UI construction. v3.10.0 reduces future risk by creating a layout model, but v3.10.1 should extract reusable panel-host helpers.

## Next architecture milestone

v3.10.1 should add collapsible panel hosts backed by the Layout State Model.
