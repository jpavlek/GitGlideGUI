# Git Glide GUI v3.10.0 Roadmap Review

## Current milestone

v3.10.0 implements the Modular Layout State Model.

This is the correct next step after v3.9.0 and v3.9.1 because conflict recovery and branch cleanup added valuable workflow features but also increased layout pressure.

## Value

Expected product effect:

- clearer layout persistence behavior
- explicit save/discard/reset controls
- safer path toward collapsible panels
- safer path toward stackable and dockable workspaces
- lower risk of adding more workflow panels into a fixed layout

## Included

- layout core module
- Pester tests
- Appearance-tab controls
- save policy selector
- docs and static smoke markers

## Excluded

- full docking engine
- drag-and-drop panel rearrangement
- named profile editor
- rewritten UI framework

## Recommended next sequence

```text
v3.10.1  Collapsible Panel Host
v3.10.2  Stackable Workspace Groups
v3.10.3  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```
