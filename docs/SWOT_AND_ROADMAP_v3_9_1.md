# Git Glide GUI v3.9.1 SWOT and Roadmap

## Theme

v3.9.1 focuses on branch cleanup and remote branch hygiene.

It builds on:

- v3.8.1 stable runtime versioning and reduced release churn
- v3.8.2 metrics, value, and technical-debt observability
- v3.9.0 guided conflict resolution assistant

## Strengths

- Adds a practical post-release cleanup workflow.
- Keeps local and remote branch deletion previewable.
- Blocks protected branches such as `main`, `develop`, `release/*`, `hotfix/*`, and the current branch.
- Uses a UI-free command-plan module with Pester tests.
- Reduces reliance on manual branch cleanup commands.

## Weaknesses

- The Integrate tab is becoming more crowded.
- Remote branch cleanup still requires careful user judgment.
- GUI behavioral automation remains limited.
- The assistant is not yet a full branch lifecycle dashboard.

## Opportunities

- Add branch age and last-commit metadata.
- Add stale remote-tracking branch explanations after fetch/prune.
- Add a release scorecard that includes branch hygiene status.
- Integrate cleanup recommendations with release tagging.
- Move toward v3.10 modular layout panels.

## Threats

- Branch deletion can cause data loss if protections are weakened.
- Too many workflow controls can overwhelm beginners.
- Layout pressure will continue until v3.10 modular layout work begins.

## Roadmap

### v3.9.1 — Branch Cleanup and Remote Branch Hygiene Assistant

- Inspect local branch tracking state.
- Inspect remote branches.
- Fetch and prune remote-tracking refs.
- Classify safe local cleanup candidates.
- Preview local branch deletion.
- Preview remote branch deletion.
- Block protected branches.
- Require confirmation before deletion.

### v3.10.0 — Modular Layout State Model

Introduce a layout model independent of direct WinForms control placement.

### v3.10.1 — Collapsible and Stackable Panels

Add reusable panel hosts for crowded workflows.

### v3.10.2 — Dockable Layout Simulation

Use WinForms split containers and tab groups to simulate flexible workspaces.