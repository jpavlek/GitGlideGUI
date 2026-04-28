# Git Glide GUI v3.9.1 Roadmap Review

## Current milestone

v3.9.1 focuses on branch cleanup and remote branch hygiene.

This is the right next step after v3.9.0 because conflict resolution improves recovery during integration, while branch cleanup improves hygiene after integration.

## Problem solved

```bat
git branch -vv
git branch -r
git fetch origin --prune
git branch --merged main
git branch -r --merged origin/main
git branch -d <branch>
git push origin --delete <branch>
```

## Expected value

```text
Feature points:        +4
Risk-reduction points: +4
Problem areas:
  branch.cleanup
  remote.hygiene
  git.decision_safety
```

## Next roadmap step

After v3.9.1, the main risk becomes UI complexity. The correct next priority is v3.10.0 modular layout state and collapsible/stackable/dockable panel foundations.
