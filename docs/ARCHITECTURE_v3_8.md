# Git Glide GUI v3.8.0 Architecture

v3.8.0 keeps the v3.7 split-script layout and adds branch relationship logic to the history workflow.

## Runtime entrypoint

```text
scripts/windows/GitGlideGUI-v3.8.0.ps1
```

## Branch relationship logic

Pure helper functions live in:

```text
modules/GitGlideGUI.Core/GitHistoryOperations.psm1
```

The UI uses read-only command plans for:

```text
git rev-list --left-right --count <left>...<right>
git merge-base --short <left> <right>
git log --oneline --left-right --cherry-pick -n12 <left>...<right>
```
