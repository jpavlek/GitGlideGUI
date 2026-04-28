# Git Glide GUI v3.9.0 Roadmap Review

## Current milestone

v3.9.0 focuses on guided conflict resolution.

This is the correct next step after the v3.8 line because the product now has:

- branch relationship inspection
- stable runtime filenames
- centralized version handling
- metrics and value observability

Those improvements make the project ready for another high-value workflow feature.

## Why conflict resolution is the right priority

Conflict recovery is one of the most stressful and error-prone Git workflows.

Common user questions:

- Which files are actually conflicted?
- Did I remove all conflict markers?
- Should I choose ours or theirs?
- What does continue do for merge vs cherry-pick vs rebase?
- Is abort safe?
- Can I stage this file now?

v3.9.0 answers these questions without hiding Git. It gives the user guidance, command previews, and safety checks.

## Value of v3.9.0

Expected metrics model delta:

```text
Feature points:        +5
Risk-reduction points: +5
Problem areas:
  conflict.recovery
  git.decision_safety
```

Expected product effect:

- lower risk of staging unresolved conflict markers
- faster conflict recovery
- clearer recovery decisions
- fewer accidental destructive choices
- stronger foundation for future visual merge tooling

## Boundaries

v3.9.0 should remain focused and safe.

Included:

- list conflicted files
- scan conflict markers
- block stage-resolved if markers remain
- command plans for ours/theirs/stage/continue/abort
- documentation and tests

Excluded:

- automatic conflict resolution
- AI conflict resolution
- full visual merge editor
- binary conflict resolution
- batch conflict resolution

## Workflow gaps still visible from the development thread

### Branch cleanup and hygiene

The thread repeatedly used:

```bat
git branch -vv
git branch -r
git fetch origin --prune
git branch --merged main
git branch -r --merged origin/main
git branch -d <branch>
git push origin --delete <branch>
```

This should become a Branch Cleanup Assistant.

### Remote tracking setup

The thread used:

```bat
git fetch origin
git switch --track origin/<branch>
git branch -vv
```

This should become a Remote Branch Sync Assistant or part of branch cleanup.

### Release tag verification

The thread used:

```bat
git tag -a <version> -m "Release ..."
git push origin <version>
git show --no-patch --decorate <version>
git branch -a --contains <version>
```

This should become a Release Tagging and Verification Assistant.

### Patch/ZIP import workflow

The thread used ZIP extraction and patch application. The GUI does not yet help validate incoming patch packages.

Potential future feature:

- Patch Package Import Assistant
- ZIP diff preview
- expected file list
- apply/revert guidance

### Metrics interpretation in the GUI

v3.8.2 generates metrics, but the GUI does not yet provide a metrics dashboard.

Potential future feature:

- Release Scorecard Panel
- technical-debt trend
- feature-point trend
- package change surface
- release churn indicator

### Layout architecture

The thread revealed a growing need to switch between many contexts:

- changed files
- diff preview
- command output
- recovery
- conflict assistant
- branch relationships
- history
- metrics
- release notes

This should drive v3.10.0 layout modularization.

## Recommended next sequence

```text
v3.9.0   Guided Conflict Resolution Assistant
v3.9.1   Branch Cleanup and Remote Branch Hygiene Assistant
v3.10.0  Modular Layout State Model
v3.10.1  Collapsible and Stackable Panels
v3.10.2  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```