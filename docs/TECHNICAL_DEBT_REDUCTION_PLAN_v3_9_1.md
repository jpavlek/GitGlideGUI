# Git Glide GUI v3.9.1 Technical Debt Reduction Plan

## Current debt focus

v3.9.1 reduces manual branch cleanup risk but adds more controls to an already crowded WinForms layout.

The main debt risk is layout complexity, not Git command planning.

## Debt reduced in v3.9.1

- Branch cleanup logic is extracted into a UI-free module.
- Branch cleanup command planning is testable.
- Protected branch checks are centralized.
- Local and remote branch deletion previews are reusable.
- Cleanup recommendations are separated from UI rendering.

## Debt added or still present

- More controls in the Integrate tab.
- No generic workspace panel model yet.
- GUI behavior tests are still limited.
- Static smoke tests still rely partly on marker strings.
- Layout save/discard behavior is not explicit enough.

## Technical debt targets

### Runtime script size

Keep each GUI implementation part below:

```text
4000 lines
```

Continue watching:

```text
scripts/windows/GitGlideGUI.part05-ui.ps1
```

### Core logic

New Git behavior should follow this pattern:

```text
Core module
  -> Pester tests
    -> GUI adapter
      -> static smoke markers
        -> documentation
```

## Near-term plan

### v3.10.0 — Layout State Model

Introduce a layout state model independent of WinForms controls.

Minimum fields:

- schemaVersion
- activeProfile
- savePolicy
- panel visibility
- panel collapsed state
- dock/anchor preference
- split distances or weights
- tab stack membership

### v3.10.1 — Collapsible Panel Host

Create reusable helpers for collapsible, restorable panels.

Candidate helpers:

- New-GitGlidePanelHost
- Set-GitGlidePanelCollapsed
- Save-GitGlidePanelState
- Restore-GitGlidePanelState

### v3.10.2 — Stackable Workspace Groups

Group related workflows:

- History + Branch Relationships + Metrics
- Recovery + Conflict Assistant
- Integrate + Branch Cleanup
- Output + Command Preview + Logs

## Summary

v3.9.1 reduces branch hygiene risk while increasing layout pressure.

The next major technical-debt reduction milestone should be v3.10.0 modular layout architecture.