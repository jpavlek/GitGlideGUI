# Git Glide GUI v2.8.2 - Startup Choice and Single-Item Diff Hotfix

## Fixed

- Replaced the startup repository-choice click handlers with native WinForms `DialogResult` buttons.
- Removed the duplicate fourth `Continue without repo` button from the startup dialog.
- Fixed strict-mode `.Count` access in `GitStagingOperations.psm1` when a diff preview contains exactly one path.
- Prevents the refresh failure seen after initializing a repository inside the app:

```text
Refresh failed: Exception setting "SelectedIndex": "The property 'Count' cannot be found on this object."
```

## Why this matters

The initial repository dialog is now simpler and more robust: exactly three intention-based choices are shown and each one closes the dialog through native WinForms behavior rather than a PowerShell nested closure.

The staging/diff helper module now treats single-item results as arrays before checking `.Count`, which is important under module strict mode and Windows PowerShell 5.1.

## Recommended Windows smoke test

1. Start `git-glide-gui.bat` from the extracted tool folder.
2. Confirm that each startup card works:
   - `Open existing repo` opens the folder picker.
   - `Init new repo` opens the init flow.
   - `Continue without repo` starts the GUI without repository commands.
3. In a normal non-Git folder, use `Init new repo`.
4. Confirm refresh does not fail with the `SelectedIndex` / `Count` error.
5. Confirm untracked files can be selected without crashing the diff preview.
