# Git Glide GUI v3.10.1 Roadmap Review

## Current milestone

v3.10.1 implements the Collapsible Panel Host.

This is the correct follow-up to v3.10.0 because the layout state model needed a visible user-facing behavior before larger stackable or dockable layouts could be justified.

## Why this is the right priority

The product has accumulated many useful panels:

- repository status
- workflow actions
- changed files
- diff preview
- live output
- recovery
- history
- branch cleanup
- conflict assistant
- metrics and layout state

Collapsible panels reduce crowding without removing features.

## Included

- core collapsed-state helpers
- panel last-size helpers
- GUI panel host selector
- collapse / restore / restore all controls
- save panel state integration
- static smoke and Pester coverage

## Excluded

- true docking
- drag-and-drop panel rearrangement
- tab stack editor
- multi-monitor workspace profiles

## Recommended next sequence

```text
v3.10.2  Stackable Workspace Groups
v3.10.3  Explicit Layout Save/Discard/Profile Polish
v3.10.4  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```
