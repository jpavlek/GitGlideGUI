# Git Glide GUI v3.0 Release Notes

## Summary

v3.0 stabilizes the v2.9 branch-workflow release and continues the roadmap with stash-operation extraction, stash workflow tests, better recovery guidance, and a first Windows smoke-launch script.

## Fixed

- Fixed the v2.9 startup parser regression caused by accidental switch-case statements being inserted inside `Set-SuggestedNextActionFromSnapshot`.
- The launcher now targets `scripts/windows/GitGlideGUI-v3.0.ps1`.

## Added

- `modules/GitGlideGUI.Core/GitStashOperations.psm1`, a UI-free module for stash command planning and recovery guidance.
- `tests/GitStashOperations.Tests.ps1` for stash command-plan and guidance tests.
- `tests/GitRepositoryStashWorkflow.Tests.ps1` for temporary-repository stash workflow tests.
- `scripts/windows/smoke-launch.ps1`, which runs the GUI script with `-SmokeTest` so Windows can catch parser/import regressions without opening the GUI.
- `-SmokeTest` parameter in the main GUI script.

## Improved

- Stash previews now use the extracted stash module when available.
- Stash apply/pop now run with explicit failure handling and show recovery guidance after conflicts, overwrite risks, invalid stash references, or index-restoration issues.
- Suggested Next Action can now offer a confirmed stash action for dirty work trees without staged or conflicted files.
- Repository-status guidance now explains that the user can review, stage, or stash dirty work before switching, pulling, or merging.

## Recommended Windows validation

From the extracted package root:

```bat
scripts\windows\run-quality-checks.bat
```

Or for the parser/import smoke check only:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
```

## Notes

Live WinForms testing still requires Windows. The artifact environment statically validated the package and ZIP integrity.
