# Git Glide GUI v3.1 Release Notes

## Focus

v3.1 continues the roadmap-driven modular extraction work by moving release-tag command planning into a UI-free module and adding temporary-repository tests around tag workflows.

## Added

- `modules/GitGlideGUI.Core/GitTagOperations.psm1`
  - tag-name validation
  - annotated-tag command planning
  - lightweight-tag command planning
  - selected-tag display parsing
  - tag list/details command planning
  - push selected tag / push all tags command planning
  - local and remote delete command planning
  - checkout tag / branch from tag command planning
  - local/remote delete safety guidance

- `tests/GitTagOperations.Tests.ps1`
  - validates tag names
  - verifies annotated and lightweight tag previews
  - verifies push/delete/checkout/branch previews
  - verifies local versus remote delete safety guidance

- `tests/GitRepositoryTagWorkflow.Tests.ps1`
  - creates annotated tags in a temporary repository
  - creates lightweight tags in a temporary repository
  - deletes only the selected local tag through the generated plan
  - verifies remote command previews without requiring a remote

- `scripts/windows/package-release.ps1`
  - release packaging gate that refuses to create a ZIP if mandatory checks fail
  - makes the Windows smoke-launch parser/import check mandatory before packaging

## Changed

- Main script updated to `scripts/windows/GitGlideGUI-v3.1.ps1`.
- `git-glide-gui.bat` now launches the v3.1 script.
- The Tags / Release UI now uses `GitTagOperations.psm1` command plans where possible.
- The smoke-launch script now targets v3.1.
- The static package smoke test now checks the tag module, tag tests, and mandatory packaging gate.

## Notes

The artifact was statically validated in the artifact environment. Live WinForms launch testing still needs Windows PowerShell/WinForms on Windows 10/11.
