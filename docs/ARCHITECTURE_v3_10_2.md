# Git Glide GUI v3.10.2 Architecture

## Theme

Release hygiene and layout-host consistency before new layout complexity.

v3.10.2 keeps the same architectural boundary as v3.10.1: core layout state remains UI-free, and WinForms control mapping remains in the GUI adapter layer.

## Core module responsibilities

```text
modules/GitGlideGUI.Core/GitLayoutState.psm1
```

The module owns:

- default layout state
- canonical panel ID normalization
- canonical panel registry
- panel state lookup
- panel collapsed-state mutation
- panel last-size metadata
- save policy normalization
- layout summary formatting
- collapsible panel host summary formatting

## GUI adapter responsibilities

The GUI owns:

- mapping canonical panel IDs to concrete `SplitContainer` controls
- preventing both sides of the same splitter from being collapsed
- updating WinForms `Panel1Collapsed` and `Panel2Collapsed`
- refreshing the Appearance-tab panel selector
- saving updated panel state into config

## Quality gate architecture

The full quality gate now refreshes metrics first, then runs static release consistency checks. This ordering prevents stale generated reports from passing as release artifacts.

The static smoke test now catches:

- stale README / START_HERE current-version references
- stale metrics report or latest metrics snapshot
- stale launcher references to missing versioned runtime scripts
- oversized split script parts
- unresolved conflict markers in stable implementation files

## Risk control

v3.10.2 intentionally avoids stackable panels or docking simulation. It hardens the baseline before increasing UI layout complexity.
