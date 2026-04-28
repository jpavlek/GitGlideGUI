# Future GUI Layout Architecture Plan

## Goal

Move from a mostly fixed WinForms layout to modular, user-controlled workspace widgets.

Desired behavior:

- Collapsible panels.
- Stackable panels.
- Resizable panels.
- Dockable/anchorable panels.
- Saved named layouts.
- Per-session choice to save or discard layout changes.
- Reset layout.
- Export/import layout.
- Layout profiles for Simple, Workflow, Expert, Recovery, Metrics, and Release modes.

## Recommended staged implementation

### v3.10.0 Layout State Model

Add a layout model independent of WinForms controls:

```json
{
  "schemaVersion": 1,
  "activeProfile": "workflow",
  "profiles": {
    "workflow": {
      "panels": {
        "changedFiles": { "visible": true, "dock": "left", "weight": 0.35 },
        "preview": { "visible": true, "dock": "fill", "weight": 0.45 },
        "output": { "visible": true, "dock": "bottom", "height": 220 }
      }
    }
  },
  "savePolicy": "ask-on-exit"
}
```

### v3.10.1 Collapsible Panels

Implement a reusable panel wrapper:

```text
New-GitGlidePanelHost
Set-GitGlidePanelCollapsed
Save-GitGlidePanelState
Restore-GitGlidePanelState
```

### v3.10.2 Stackable Workspaces

Support tab stacks: History + Branch relationships + Metrics, Recovery + Conflict assistant, Changed files + Tracked file browser.

### v3.10.3 Docking Simulation

WinForms does not provide Visual-Studio-grade docking natively. Simulate it with nested SplitContainers, TabControls, and a layout model.

### v3.10.4 Save/Discard Layout on Exit

Add explicit controls: Save layout now, Discard session layout changes, Reset layout, Ask on exit, Always save layout, Never save layout.

## Why not do this inside v3.9.0?

v3.9.0 should stay focused on conflict resolution. Dockable layout is a large architectural milestone and should not be mixed with conflict-assistant behavior.
