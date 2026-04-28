# Git Glide GUI v3.9.0 SWOT and Roadmap

## Theme

v3.9.0 focuses on guided conflict resolution and safer recovery workflows.

It builds on:

- v3.8.0 branch relationship understanding.
- v3.8.1 stable runtime versioning and reduced release churn.
- v3.8.2 metrics, value, and technical-debt observability.

## Strengths

- Clear product direction: transparent Git workflows instead of hidden abstractions.
- Stable split-script runtime architecture from v3.8.1.
- Local quality and value metrics from v3.8.2.
- Existing Repository State Doctor and conflict-marker scanning foundation.
- v3.9.0 adds guided conflict recovery without attempting unsafe automatic resolution.
- Command plans keep Git actions visible and reviewable.
- Tests cover the new conflict assistant helpers.

## Weaknesses

- WinForms layout is still mostly fixed and increasingly crowded.
- The Recovery area now has more responsibility and needs better layout organization.
- Static smoke checks still rely partly on marker strings.
- GUI behavioral automation is still limited.
- The conflict assistant is guided, not yet a full visual three-way merge tool.
- Manual release/tag/branch-cleanup steps still require command-line support.

## Opportunities

- Add a Branch Cleanup Assistant for safely deleting merged local and remote branches.
- Add a Remote Branch Sync Assistant for fetch/prune/tracking workflows.
- Add a Release Tagging and Verification Assistant.
- Add generated release scorecards from v3.8.2 metrics.
- Modularize the GUI into reusable workspace panels.
- Add collapsible, stackable, dockable, and anchorable layout widgets.
- Add explicit layout save/discard/reset behavior on exit.
- Later, build a true visual conflict editor on top of the v3.9.0 command-plan foundation.

## Threats

- UI complexity may grow faster than layout architecture.
- Adding conflict tools without strong confirmations can create data-loss risk.
- More panels can make beginner experience worse unless progressive disclosure improves.
- Large script parts can become harder to review if layout refactoring is delayed.
- Marker-based smoke tests may miss behavior-level regressions.

## Roadmap

### v3.9.0 — Guided Conflict Resolution Assistant

- List unmerged files.
- Scan selected files for conflict marker blocks.
- Show marker count and line ranges.
- Block stage-resolved while markers remain.
- Provide previewable command plans for ours, theirs, stage resolved, continue, and abort.
- Require confirmation for destructive choices.

### v3.9.1 — Branch Cleanup and Remote Branch Hygiene Assistant

Target workflows observed in development:

```bat
git branch -vv
git branch -r
git fetch origin --prune
git branch --merged main
git branch -r --merged origin/main
git branch -d <branch>
git push origin --delete <branch>
```

Goal:

- show which branches are merged into `main` / `develop`
- distinguish local-only, remote-tracking, and stale branches
- preview safe delete commands
- require confirmation for remote deletion

### v3.10.0 — Modular Layout State Model

Introduce layout state independent of WinForms controls.

Minimum concepts:

- panel id
- visible/collapsed state
- dock/anchor preference
- split weights
- selected tab stack
- active layout profile
- save policy

### v3.10.1 — Collapsible and Stackable Panels

Add reusable panel hosts for:

- Changed Files
- Diff Preview
- Command Output
- Recovery
- Conflict Assistant
- History
- Branch Relationships
- Metrics

### v3.10.2 — Dockable Layout Simulation

Use WinForms `SplitContainer`, `TabControl`, and a layout model to simulate dockable workspaces without rewriting the product in a new UI framework.

### v3.11.0 — CI/CD and Pull Request Integration

Add CI status, PR link detection, PR creation guidance, and release readiness checks.