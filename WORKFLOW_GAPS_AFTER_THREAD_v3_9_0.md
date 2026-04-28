# Workflow Gaps Observed in This Thread

## Supported or mostly supported after v3.9.0

- Branch relationship inspection before merges.
- Conflict recovery guidance.
- Conflict marker scanning.
- Stage-resolved blocking when markers remain.
- Version source-of-truth and stable runtime scripts.
- Metrics and value observability.

## Still not fully supported

### Branch hygiene and cleanup

Used in this thread:

```bat
git branch -vv
git branch -r
git fetch origin --prune
git branch --merged main
git branch -r --merged origin/main
git branch -d <branch>
git push origin --delete <branch>
```

Needed feature: Branch Cleanup Assistant.

### Release/tag verification

Used in this thread:

```bat
git tag -a v3.8.1 -m "Release Git Glide GUI v3.8.1"
git push origin v3.8.1
git show --no-patch --decorate v3.8.1
git branch -a --contains v3.8.1
```

Needed feature: Release Tagging and Verification Assistant.

### Remote sync and tracking setup

Used in this thread:

```bat
git fetch origin
git fetch origin --prune
git switch --track origin/<branch>
git branch -vv
```

Needed feature: Remote Branch Sync Assistant.

### Patch/ZIP import workflow

Used in this thread: download ZIP, extract into repo, apply snippets, delete helper snippets, stage expected files.

Needed feature: Patch Package Import Assistant.

### Metrics interpretation and release decision support

v3.8.2 collects metrics, but the GUI does not yet show a release scorecard.

Needed feature: Generated Release Scorecard Panel.

### Layout control

The thread repeatedly required switching between docs, changed files, diffs, output, recovery, metrics, and branch information.

Needed architectural milestone: Dockable/collapsible/stackable widget layout with explicit save/discard layout controls.
