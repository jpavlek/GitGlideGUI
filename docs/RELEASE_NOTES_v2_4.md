# Git Glide GUI v2.4 Release Notes

## Main fix

v2.4 fixes the situation where Git Glide GUI was launched from the extracted tool package folder instead of a real Git repository. Earlier builds could repeatedly run commands such as:

```text
git status --porcelain=v1 --branch
fatal: not a git repository (or any of the parent directories): .git
```

## Changes

- Added `-RepositoryPath` startup parameter.
- Added repository auto-discovery from:
  - explicit `-RepositoryPath`
  - saved `LastRepositoryRoot`
  - current working directory
  - nearby parent/sibling folders
- Added **Open repo...** button in the Repository status area.
- Added startup prompt when no Git repository is selected.
- Persisted the selected repository as `LastRepositoryRoot` in `GitGlideGUI-Config.json`.
- Guarded status, branch, stash, and tag refresh paths so they do not spam failing Git commands when no repository is selected.
- Added a clearer suggested next action: **Open a Git repository before running Git operations.**
- Kept `git-flow-gui2.bat` as a compatibility launcher.

## Why this matters

The application package and the target repository are often different folders. A Git GUI should not assume the extracted tool folder is the repository. v2.4 makes that distinction explicit and recoverable.
