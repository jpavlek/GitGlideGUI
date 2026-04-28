# Git Glide GUI v3.10.0 Technical Debt Reduction Plan

## Current debt focus

v3.10.0 addresses layout debt. The main risk in the product is no longer only Git command safety; it is the number of workflows competing for fixed UI space.

## Debt reduced

- Layout state is extracted into a UI-free module.
- Save policy is explicit.
- Splitter state can be summarized and tested.
- Future panel hosts can use durable layout data instead of ad hoc control values.

## Debt still present

- `part05-ui.ps1` remains large.
- Panels are not collapsible yet.
- Panels are not stackable yet.
- Docking is not implemented yet.
- GUI behavioral automation remains limited.

## Near-term plan

### v3.10.1 — Collapsible Panel Host

Create reusable helpers:

```text
New-GitGlidePanelHost
Set-GitGlidePanelCollapsed
Save-GitGlidePanelState
Restore-GitGlidePanelState
```

### v3.10.2 — Stackable Workspace Groups

Group related workflows:

- History + Branch Relationships + Metrics
- Recovery + Conflict Assistant
- Integrate + Branch Cleanup
- Output + Command Preview + Logs

### v3.10.3 — Dockable Layout Simulation

Use nested `SplitContainer`, `TabControl`, and the Layout State Model to simulate Visual-Studio-style workspaces without changing UI framework.

## Summary

v3.10.0 does the necessary architectural groundwork. The next iteration should build the first reusable collapsible panel host instead of adding another large workflow panel.
