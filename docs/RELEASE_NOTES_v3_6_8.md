# Git Glide GUI v3.6.8 Release Notes

## Focus

v3.6.8 closes a workflow gap around clean tracked files. The Changed Files list shows modified/staged/deleted/renamed/untracked paths, but clean tracked files were not selectable for replacement or removal workflows.

## Added

- Added **Stage -> Browse tracked files**.
- Lists tracked files with `git ls-files --cached --full-name`.
- Allows **Remove from Git and disk** via `git rm -- <file>`.
- Allows **Stop tracking, keep local** via `git rm --cached -- <file>`.
- Keeps confirmation dialogs before destructive or tracking-changing operations.

## Why it matters

Developers can now replace or remove an unchanged tracked file without editing it first just to make it appear in Changed Files.
