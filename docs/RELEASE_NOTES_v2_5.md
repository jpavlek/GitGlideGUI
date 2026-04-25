# Git Glide GUI v2.5 Release Notes

## Main improvement

v2.5 improves the no-repository startup experience. A folder without `.git` can mean either:

- the user opened the wrong folder, or
- the user wants to start a new Git repository.

The GUI now supports both cases explicitly.

## Added

- **New repo...** button in the Repository status area.
- Startup prompt with three choices:
  - open an existing Git repository,
  - initialize a folder as a new Git repository,
  - continue without a repository.
- Initialization workflow using `git init -b <main branch>`.
- Fallback for older Git versions: `git init` followed by `git branch -M <main branch>`.
- Confirmation before initializing a non-empty folder.
- Audit log entries for repository initialization.
- Pester test for temporary repository initialization.

## Preserved

- Existing repository picker.
- `git-glide-gui.bat` primary launcher.
- `git-flow-gui2.bat` compatibility launcher.
- v2.4 protection against repeated `fatal: not a git repository` log spam.

## Manual Windows test

1. Start `git-glide-gui.bat` from the extracted tool folder.
2. Choose **No** in the startup prompt to initialize a new repository.
3. Select an empty temporary folder.
4. Confirm that `git init` succeeds and the Repository status area points to the new folder.
5. Repeat with a non-empty folder and confirm the extra confirmation dialog appears.

