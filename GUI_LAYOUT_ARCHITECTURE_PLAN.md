# Git Glide GUI Future Layout Architecture Plan 

## Goal

Move from a mostly fixed WinForms layout to modular, user-controlled workspace widgets.

Desired behavior:

- Collapsible panels.
- Stackable panels.
- Resizable panels.
- Dockable/anchorable panels.
- Saved named layouts.
- Explicit save/discard/reset layout controls.
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
  "savePolicy": "manual"
}
```

Note: v3.10.2 renamed the visible policy to `manual`. Legacy `ask-on-exit` values are still accepted and normalized to `manual` because shutdown must remain non-modal.

### v3.10.1 Collapsible Panels

Implement reusable panel-host behavior:

```text
Get-GitGlidePanelHostDefinitions
Toggle-GitGlidePanelCollapsed
Restore-GitGlidePanelHostState
Save-GitGlidePanelHostState
Format-GitGlidePanelHostSummary
```

Supported canonical panel IDs include:

```text
repositoryStatus
topWorkflow
changedFiles
diffAndOutput
diffPreview
liveOutput
```

### v3.10.2 Release hygiene and layout-host consistency

Stabilize the v3.10.1 Collapsible Panel Host before adding more layout complexity.

Scope:

- Align README, START_HERE, release notes, manifest, metrics report, and snapshots with VERSION.
- Harden the quality gate.
- Keep static smoke checks non-mutating.
- Refresh metrics after functional validation.
- Add a separate release artifact consistency check after metrics refresh.
- Normalize legacy ask-on-exit to manual.
- Keep shutdown non-modal.
- Align WinForms panel-host IDs with the canonical Layout State Model registry.

### v3.10.3 Stackable Workspaces

Support tab stacks and grouped workspaces:
- History + Branch relationships + Metrics.
- Recovery + Conflict Assistant + Repository State Doctor.
- Changed files + Tracked file browser.
- Diff preview + Command preview + Live output.
- Release checklist + Tags + Quality gate output.

Implementation direction:

- Use TabControls inside existing SplitContainers first.
- Store stack membership in the Layout State Model.
- Keep the first implementation conservative and reversible.
- Avoid introducing true drag-and-drop docking yet.

### v3.10.4 Explicit layout profile polish

Improve saved layout controls:

- Save layout now.
- Discard session layout changes.
- Reset layout.
- Save policy: manual, always, never.
- Named layout profiles.
- Profile selector for Simple, Workflow, Expert, Recovery, Metrics, and Release modes.

Important: do not reintroduce modal ask-on-exit behavior. It should remain a legacy config alias only.

### v3.10.5 Docking Simulation

WinForms does not provide Visual-Studio-grade docking natively. Simulate it with nested SplitContainers, TabControls, and the Layout State Model.

Scope:

- Dock-like placement presets.
- Move panel between known regions.
- Anchor panel left/right/top/bottom/fill.
- Save and restore dock simulation state.
- Keep all operations explicit and recoverable.

### v3.10.6 Export/import layout

Add portable layout exchange:

- Export current layout profile to JSON.
- Import layout profile from JSON.
- Validate schema version.
- Reject unknown or unsafe panel IDs.
- Offer reset if imported layout is incompatible.

