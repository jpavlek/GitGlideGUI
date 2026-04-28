# Git Glide GUI v3.9.1 Branch Cleanup and Remote Branch Hygiene Assistant

## Purpose

v3.9.1 adds a guided assistant for cleaning up local and remote branches after a release or merge cycle.

The assistant exists because branch cleanup is easy to do incorrectly from the command line. Deleting the wrong branch, deleting a branch before it reaches `main`, or confusing local branches with remote-tracking branches can create avoidable recovery work.

## Supported workflow

```bat
git fetch origin --prune
git branch -vv
git branch -r
git branch --merged main
git branch --merged develop
git branch -r --merged origin/main
git branch -r --merged origin/develop
git branch -d <branch>
git push origin --delete <branch>
```

## What it should show

- local branches safe to delete
- remote branches safe to delete
- branches already merged into `main`
- branches merged into `develop` but not confirmed in `main`
- local-only branches
- remote-tracking branches
- stale remote-tracking branches after fetch/prune
- protected branches that must not be deleted

## Protected branches

- `main`
- `develop`
- `release/*`
- `hotfix/*`
- the current branch
- branches not confirmed as merged

## Safety model

```text
Inspect branch state
  -> classify cleanup candidates
    -> preview exact Git command
      -> ask for confirmation
        -> execute only the selected cleanup action
          -> refresh branch state
```

## Non-goals

v3.9.1 does not automatically delete branches, rewrite history, force-delete by default, or delete protected workflow branches.
