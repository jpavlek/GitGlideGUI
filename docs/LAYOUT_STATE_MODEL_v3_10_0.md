# Git Glide GUI v3.10.0 Layout State Model

## Purpose

v3.10.0 introduces a UI-independent Layout State Model. The goal is to stop treating layout as scattered WinForms splitter values and start treating it as product state that can be saved, inspected, reset, and later extended into collapsible, stackable, and dockable panels.

## What is modeled

The model stores:

- schema version
- active layout profile
- save policy
- panel identity
- panel visibility
- collapsed state
- dock preference
- split weights
- splitter distances
- optional panel height

## Save policy

Supported values:

```text
ask-on-exit
always
never
```

`ask-on-exit` gives the user control when closing the GUI. `always` preserves the previous automatic behavior. `never` allows temporary session resizing without changing the saved layout.

## Current GUI integration

The Appearance tab now exposes layout controls:

- Save layout now
- Show layout state
- Discard session layout
- Reset layout
- Save policy selector

Existing splitters continue to work. v3.10.0 does not rewrite the UI; it creates the data model needed for safer future layout refactoring.

## Future use

v3.10.1 can add collapsible panel hosts.

v3.10.2 can add stackable workspace groups.

v3.10.3 can simulate dockable workspaces with WinForms SplitContainers, TabControls, and the layout model.
