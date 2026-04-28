# Git Glide GUI v3.9.0 Patch Snippets

## VERSION

```text
3.9.0
```

## manifest.json

Update version to `3.9.0`, iteration focus to `v3.9.0 guided conflict resolution assistant`, and add `modules/GitGlideGUI.Core/GitConflictAssistant.psm1` to `core_modules`.

## tests/static_smoke_test.py

Add required files:

```python
"modules/GitGlideGUI.Core/GitConflictAssistant.psm1",
"tests/GitConflictAssistant.Tests.ps1",
"docs/CONFLICT_RESOLUTION_ASSISTANT_v3_9.md",
"docs/RELEASE_NOTES_v3_9_0.md",
```

Add marker checks:

```python
require_markers(
    "modules/GitGlideGUI.Core/GitConflictAssistant.psm1",
    [
        "Get-GgcaUnmergedFilesCommandPlan",
        "Get-GgcaConflictMarkerScanForText",
        "Get-GgcaCheckoutOursCommandPlan",
        "Get-GgcaCheckoutTheirsCommandPlan",
        "Test-GgcaStageResolvedFileAllowed",
        "Get-GgcaContinueOperationCommandPlan",
        "Get-GgcaAbortOperationCommandPlan",
    ],
    "conflict assistant module",
)

require_markers(
    "tests/GitConflictAssistant.Tests.ps1",
    [
        "GitConflictAssistant command plans",
        "GitConflictAssistant conflict marker scanning",
        "blocks staging when markers remain",
    ],
    "conflict assistant tests",
)
```

After UI integration, add split markers:

```python
"Conflict Resolution Assistant",
"Refresh-ConflictAssistant",
"Show-ConflictAssistantSelectedFileScan",
"Invoke-ConflictAssistantStageResolved",
```

## scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1

Import the new module near the other module imports:

```powershell
Import-Module (Join-Path $script:CoreModuleRoot 'GitConflictAssistant.psm1') -Force
```

If the bootstrap uses a module list, add:

```powershell
'GitConflictAssistant.psm1'
```

## UI integration

Suggested function names:

```powershell
function Refresh-ConflictAssistant { ... }
function Show-ConflictAssistantSelectedFileScan { ... }
function Invoke-ConflictAssistantUseOurs { ... }
function Invoke-ConflictAssistantUseTheirs { ... }
function Invoke-ConflictAssistantStageResolved { ... }
function Invoke-ConflictAssistantContinue { ... }
function Invoke-ConflictAssistantAbort { ... }
```

Minimum behavior:

- `Refresh-ConflictAssistant` runs `git diff --name-only --diff-filter=U`.
- Parse with `ConvertFrom-GgcaUnmergedFileList`.
- Selecting a file runs `Get-GgcaConflictMarkerScanForFile`.
- `Invoke-ConflictAssistantStageResolved` calls `Test-GgcaStageResolvedFileAllowed` and blocks if markers remain.
- Ours/theirs actions use `Get-GgcaCheckoutOursCommandPlan` and `Get-GgcaCheckoutTheirsCommandPlan`.
- Continue/abort actions use `Get-GgcaContinueOperationCommandPlan` and `Get-GgcaAbortOperationCommandPlan`.

## metrics/feature_manifest.json

Add the feature from `metrics/feature_manifest_v3_9_patch.json` to the `features` array.

Expected score delta:

```text
Feature points: +5
Risk-reduction points: +5
Problem areas: conflict.recovery, git.decision_safety
```
