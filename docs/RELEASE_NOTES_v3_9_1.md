# Git Glide GUI v3.9.1 Release Notes

## Theme

Branch Cleanup and Remote Branch Hygiene Assistant.

## Added

- Branch cleanup core module.
- Local branch tracking parser for `git branch -vv`.
- Remote branch parser for `git branch -r`.
- Merged branch parsers for local and remote cleanup decisions.
- Protected-branch checks for `main`, `develop`, `release/*`, `hotfix/*`, and the current branch.
- Fetch/prune command plan.
- Local branch delete command plan.
- Remote branch delete command plan.
- Branch cleanup recommendation helper.
- Branch cleanup summary formatter.
- Pester tests for parsing, protection, command plans, and recommendations.

## Safety

- No automatic deletion.
- Protected branches are blocked.
- Remote deletion always requires confirmation.
- Local deletion defaults to `git branch -d`, not force delete.
- Every action remains previewable.

## Why this release matters

After v3.9.0 improved conflict recovery, the next visible workflow gap was branch hygiene after releases and merges. The project repeatedly needed to inspect remote branches, check tracking status, prune stale refs, and decide which branches were safe to remove.
