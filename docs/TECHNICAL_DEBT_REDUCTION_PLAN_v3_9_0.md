# Git Glide GUI v3.9 Technical Debt Reduction Plan

## Current debt focus

v3.9.0 adds an important recovery workflow, but it also increases GUI complexity. The main debt risk is that recovery, history, metrics, branch relationships, changed files, diff preview, and command output compete for the same fixed layout space.

## Debt reduced in v3.9.0

- Conflict assistant logic is extracted into a UI-free module.
- Conflict command planning is testable.
- Conflict marker scanning is reusable.
- Stage-resolved safety decision is centralized.
- Operation-aware continue/abort command plans avoid duplicated UI logic.
- Conflict assistant behavior is documented.

## Debt added or still present

- More UI controls in the existing fixed WinForms layout.
- Recovery workflow has more responsibilities.
- Static smoke tests still use marker checks.
- GUI behavioral tests are still limited.
- Layout save behavior is not explicit enough.
- No generic collapsible/dockable workspace model yet.

## Technical debt targets

### Runtime script size

Keep each GUI implementation part below:

```text
4000 lines
```

Continue watching pressure in:

```text
scripts/windows/GitGlideGUI.part05-ui.ps1
```

### Core logic

New Git behavior should be implemented as UI-free module functions first.

Preferred pattern:

```text
Core module
  -> Pester tests
    -> GUI wrapper
      -> static smoke markers
        -> documentation
```

### Conflict assistant

Keep v3.9.0 conservative.

Avoid adding:

- automatic conflict resolution
- AI conflict resolution
- inline three-way editor
- batch conflict resolution

until the guided workflow is stable.

## Near-term debt reduction plan

### v3.9.1 — Branch Cleanup and Remote Branch Hygiene Assistant

Extract branch cleanup helpers into a testable module.

Candidate commands:

```bat
git fetch origin --prune
git branch -vv
git branch --merged main
git branch -r --merged origin/main
git branch -d <branch>
git push origin --delete <branch>
```

Goal:

- identify safely merged local branches
- identify safely merged remote branches
- distinguish stale remote-tracking refs
- preview deletion commands
- require confirmation for remote deletion

### v3.10.0 — Layout State Model

Introduce a layout state model independent of current WinForms controls.

Minimum fields:

- schemaVersion
- activeProfile
- savePolicy
- panel visibility
- panel collapsed state
- panel dock/anchor preference
- split distances or weights
- tab stack membership

### v3.10.1 — Collapsible Panel Host

Create reusable helpers:

```text
New-GitGlidePanelHost
Set-GitGlidePanelCollapsed
Save-GitGlidePanelState
Restore-GitGlidePanelState
```

### v3.10.2 — Stackable Workspace Groups

Candidate stacks:

- History + Branch Relationships + Metrics
- Recovery + Conflict Assistant
- Changed Files + Tracked File Browser
- Output + Command Preview + Logs

### v3.10.3 — Explicit Layout Save/Discard

Add controls:

- Save layout now
- Discard session layout changes
- Reset layout
- Ask on exit
- Always save layout
- Never save layout

## Smoke-test improvements

Current static smoke is valuable but marker-heavy.

Improve gradually by adding:

- manifest schema validation
- module export validation
- docs link validation
- generated metrics validation
- Pester coverage for every new command-plan module

## Release-process improvements

After v3.9.0, add GUI support for:

- tag creation
- tag push
- tag containment verification
- release notes validation
- package ZIP validation
- release scorecard generation

## Summary

v3.9.0 reduces conflict-recovery debt while increasing layout pressure.

Therefore the next major technical-debt reduction milestone should not be another large workflow panel. It should be the v3.10 modular layout foundation.