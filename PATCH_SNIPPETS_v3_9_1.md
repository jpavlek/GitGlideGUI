# Git Glide GUI v3.9.1 Patch Snippets

## New files

```text
modules/GitGlideGUI.Core/GitBranchCleanup.psm1
tests/GitBranchCleanup.Tests.ps1
docs/BRANCH_CLEANUP_ASSISTANT_v3_9_1.md
docs/RELEASE_NOTES_v3_9_1.md
docs/ROADMAP_REVIEW_v3_9_1.md
metrics/feature_manifest_v3_9_1_patch.json
```

## Required existing-file updates

1. Set `VERSION` to `3.9.1`.
2. Update `manifest.json` version, focus, and core module list.
3. Import `GitBranchCleanup.psm1` in `GitGlideGUI.part01-bootstrap-config.ps1`.
4. Add branch cleanup adapter functions to `GitGlideGUI.part04-recovery-push-stash-tags.ps1`.
5. Add Branch Cleanup Assistant controls to the Integrate tab in `GitGlideGUI.part05-ui.ps1`.
6. Add static smoke required-file and marker checks.
7. Add the v3.9.1 feature entry to `metrics/feature_manifest.json`.

## Static smoke markers

```python
require_markers(
    "modules/GitGlideGUI.Core/GitBranchCleanup.psm1",
    [
        "Get-GgbcFetchPruneCommandPlan",
        "ConvertFrom-GgbcBranchVerboseText",
        "Get-GgbcDeleteLocalBranchCommandPlan",
        "Get-GgbcDeleteRemoteBranchCommandPlan",
        "Format-GgbcBranchCleanupSummary",
    ],
    "branch cleanup module",
)
```

Split-script markers after GUI integration:

```python
"Branch Cleanup Assistant",
"Refresh-BranchCleanupAssistant",
"Show-BranchCleanupAssistant",
"Invoke-BranchCleanupDeleteSelectedLocal",
"Invoke-BranchCleanupDeleteSelectedRemote",
```

## Suggested branch

```bat
git switch develop
git pull origin develop
git switch -c feature/v3-9-1-branch-cleanup-remote-hygiene
```
