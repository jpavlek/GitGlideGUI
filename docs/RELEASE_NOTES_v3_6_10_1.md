# Git Glide GUI v3.6.10.1 - Workflow guard and merge guide hotfix

## Summary

v3.6.10.1 keeps the v3.6.10 branch-switch flexibility but adds a workflow guard so developers are less likely to accidentally commit feature work directly on `main` or `develop`.

## Fixes

- Fixed the Git Flow merge/publish guide so generated commands keep branch names on the same line.
- Fixed the failing Pester 3 test around `git merge --no-ff develop`.

## Improvements

- Added guidance before committing directly on workflow branches such as `main` and `develop`.
- The warning explains the recommended path: create a feature branch, commit there, merge feature -> develop, run quality checks, then merge develop -> main.
- The warning is advisory. Developers can still continue intentionally.

## Why this matters

Git Glide GUI should reduce accidental workflow skips without becoming more restrictive than Git. This release adds a lightweight decision checkpoint instead of blocking expert users.
