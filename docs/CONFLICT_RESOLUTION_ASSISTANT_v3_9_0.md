# Git Glide GUI v3.9.0 Conflict Resolution Assistant

## Purpose

The guided conflict resolution assistant helps users recover from merge, cherry-pick, and rebase conflicts without hiding the underlying Git commands.

The first v3.9.0 milestone is intentionally conservative. It is not a full automatic merge editor. It guides the user through conflict files, marker scans, command previews, and safe continue/abort actions.

## Supported workflow

1. Detect an active merge, cherry-pick, or rebase conflict state.
2. List unmerged files.
3. Select one conflicted file.
4. Open the file or containing folder.
5. Scan for conflict marker blocks.
6. Block staging while conflict markers remain.
7. Offer explicit command plans for use ours, use theirs, stage resolved file, continue operation, and abort operation.
8. Require confirmation for destructive choices.

## Commands used

```bat
git diff --name-only --diff-filter=U
git checkout --ours -- <file>
git checkout --theirs -- <file>
git add -- <file>
git commit
git cherry-pick --continue
git cherry-pick --abort
git rebase --continue
git rebase --abort
git merge --abort
```

## Safety principles

- No automatic conflict resolution.
- No staging while conflict markers remain.
- Ours/theirs actions are file-level and require confirmation.
- Continue/abort actions are operation-aware.
- Every command remains previewable.

## Out of scope for v3.9.0

- Full inline 3-way merge editor.
- AI-based conflict resolution.
- Syntax-aware merge resolution.
- Binary conflict resolution.
- Batch conflict resolution.
- Worktree/submodule conflict workflows.
