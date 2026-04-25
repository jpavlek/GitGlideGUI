# Git Glide GUI v3.6.4 Release Notes

v3.6.4 is a stability and first-commit workflow hotfix.

## Fixed

- Removed the unnecessary PowerShell `SplitterMoved` WinForms event handler that could surface a `PipelineStoppedException` JIT dialog during resize or shutdown.
- Fixed **Unstage selected** before the first commit. In an unborn repository, `git restore --staged -- <file>` fails because `HEAD` does not exist, so Git Glide now uses `git rm --cached -- <file>` while keeping the working-tree file.
- Added tests for the no-HEAD unstaging command plan and temporary repository workflow.

## Validation target

Expected Windows quality result after this release: all functional checks pass, with the Pester count increasing by the new staging tests.
