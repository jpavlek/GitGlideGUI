# Git Glide GUI v2.8 Release Notes

## Main focus

v2.8 continues the roadmap after v2.7 by improving trust, beginner guidance, and testability around staging and changed-file operations.

## Added

- New UI-free module:
  - `modules/GitGlideGUI.Core/GitStagingOperations.psm1`
- Extracted command planning for:
  - stage selected files
  - unstage selected files
  - stage all changes
  - selected-file diff command preview
  - status meaning text
  - renamed-file diff target resolution
- New beginner guidance labels in the main workflow tabs:
  - Setup
  - Inspect / Build
  - Stage
  - Branch
- New tests:
  - `tests/GitStagingOperations.Tests.ps1`
  - `tests/GitRepositoryStagingWorkflow.Tests.ps1`
- New roadmap review:
  - `docs/ROADMAP_REVIEW_v2_8.md`

## Improved

- Stage/unstage/diff preview behavior is now backed by reusable command-plan helpers instead of being only embedded in the WinForms script.
- Beginner mode is easier to understand because the visible tabs explain what the user should do and why.
- The next architecture step is smaller and safer: staging logic can now be tested without launching the GUI.

## Compatibility

- Primary launcher: `git-glide-gui.bat`
- Backward-compatible launcher: `git-flow-gui2.bat`
- Main script: `scripts/windows/GitGlideGUI-v2.8.ps1`

## Validation

Static package validation passed in the build environment. Live WinForms testing still requires Windows PowerShell on Windows 10/11.
