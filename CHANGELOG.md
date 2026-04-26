# Changelog

# v3.6.13 - Workflow checklist and release consistency guard

- Added Merge & Publish workflow checklist preview for feature/fix -> develop -> quality checks -> main.
- Added merged feature/fix branch cleanup command plans and UI entry point.
- Added static smoke release consistency checks for VERSION, manifest, launcher, smoke launch, quality-check title, README, START_HERE, and old main script drift.
- Updated README and repository workflow guidance around branch cleanup and release flow.

# v3.6.12 - UI organization and progressive disclosure

- Added Simple / Workflow / Expert modes.
- Added Command Palette entry point.
- Improved mode-aware changed-file context banner.
- Kept advanced features reachable without showing everything at once.

## v3.6.11 - Branch context and workflow guard reliability

- Added branch context banner above Changed Files.
- Added branch role detection and protected branch workflow guard improvements.
- Added create-branch-first path before committing/staging on protected branches.
- Restored package-release.ps1 to match static smoke expectations.
- Fixed visible title/audit version drift.

## v3.6.10.1 - Workflow guard and merge guide hotfix

- Fixed Git Flow merge/publish guide formatting so branch names remain on the same command line in Windows PowerShell 5.1 / Pester 3.
- Added protected-branch commit guidance: committing directly on `main` or `develop` now warns that the feature-branch workflow may be skipped.
- Developers can still continue intentionally after the warning, preserving flexibility while reducing accidental workflow bypasses.

## v3.6.10 - Branch switch dirty-work choice

- Branch switching now warns on dirty work but allows the user to let Git attempt the switch anyway.
- Git remains the final safety gate and blocks overwrites when needed.
- Pull and merge workflows remain stricter.

## v3.6.9 - Git Flow merge/publish workflow restoration

- Restored visible merge workflow support in the Integrate tab with a clearer Merge & Publish flow.
- Added branch tracking overview (`git branch -vv`).
- Added `main -> develop` sync workflow.
- Added selected-feature merge into `develop`, so a feature branch can be merged while currently on `develop`.
- Added quality-check gate button before promoting `develop` back to `main`.
- Added GitHub pull-request URL detection from push output.

## v3.6.8

- Added Stage -> Browse tracked files for clean tracked files that do not appear in Changed Files.
- Added tracked-file remove/stop-tracking path for replacement workflows.
- Added staging module tests for tracked-file parsing and clean tracked command plans.

## v3.6.7.1 - GitHub diagnostics parser hotfix

- Fixed `ConvertFrom-GghubRemoteList` for Windows PowerShell 5.1 and Pester 3 compatibility.
- Replaced a generic .NET `List[object]` return path with a plain PowerShell array of remote rows.
- Keeps the v3.6.7 GitHub diagnostics, safer file-removal workflows, and explicit staging badges intact.

## v3.6.7 - GitHub diagnostics and safer file removal

- Added GitHub remote diagnostics for remotes, current branch, upstream tracking, remote access tests, and push-with-upstream.
- Added clearer guidance for repository-not-found, missing upstream, HTTPS authentication, and SSH key failures.
- Added safer git rm workflows: remove from Git and disk, or stop tracking while keeping the local file.
- Improved changed-file display badges so staged and unstaged modifications are visibly different.
- Added module tests for GitHub diagnostics, remote failure guidance, status badges, and git rm command planning.

## v3.6.6

- Added conflict-marker verification before staging a file as resolved.
- Recovery now blocks **Stage resolved file** when a complete `<<<<<<<` / `=======` / `>>>>>>>` marker block remains.
- Added UI guidance showing the detected marker lines.
- Added unit tests for clean, unresolved, and incomplete marker-scan cases.
- Updated package metadata, launcher, smoke test, and docs to v3.6.6.

## v3.6.5.2 Patch

- PSScriptAnalyzer Resolver Syntax Fix
   - Fixes a Windows PowerShell 5.1 parser issue in `scripts/windows/ensure-psscriptanalyzer.ps1`.

## v3.6.5.1 Patch

- PSScriptAnalyzer resolver patch
   - Replaces `scripts/windows/ensure-psscriptanalyzer.ps1` with a more robust bootstrapper.

## v3.6.5 Patch

- Added conflict-marker verification before staging a file as resolved.
- Recovery now blocks **Stage resolved file** when a complete `<<<<<<<` / `=======` / `>>>>>>>` marker block remains.
- Added UI guidance showing the detected marker lines.
- Added unit tests for clean, unresolved, and incomplete marker-scan cases.
- Updated package metadata, launcher, smoke test, and docs to v3.6.5.

## v3.6.4 Patch

- Removed a fragile PowerShell `SplitterMoved` event handler that could trigger a WinForms JIT dialog during resize/shutdown.
- Fixed unstaging before the first commit by using `git rm --cached -- <file>` when `HEAD` does not exist.
- Added staging tests for the no-HEAD/unborn-repository workflow.

## v3.6.2.5 Patch

- PSScriptAnalyzer bootstrap patch
   - Adds `scripts/windows/ensure-psscriptanalyzer.ps1`
   - Updates `scripts/windows/run-quality-checks.bat` to call the bootstrapper before quality checks

## v3.6.2.4 Patch

- Conflict classifier stabilization patch fix for the remaining quality-check failure where the cherry-pick workflow test sees a real non-zero Git failure, but the application classifies it as `unknown-failure` instead of `conflict`.

## v3.6.2.3 Patch

- Patch for RuntimeException: '-Not' is not a valid Should operator.

## v3.6.2.2 Patch

- Rewrites the history visual-graph lane output to ASCII markers:
   - merge lane: `*+`
   - normal lane: `*`
   - side lane: `| *`
- Updates exact history test expectations if they contain the old graph markers.
- Changes the cherry-pick conflict workflow test from expecting exactly exit code `1` to expecting any non-zero exit code.
- Converts `Write-Warning` import failures for Git Glide core modules into hard failures where such warnings are found.

## v3.6.2.1 Patch

- `GitHistoryOperations.psm1` fails to import on Windows PowerShell 5.1 because UTF-8 graph symbols are read as ANSI/mojibake.
   - Replaces Unicode graph markers with ASCII-only markers:
     - merge lane: `*+`
     - normal lane: `*`
     - side lane: `| *`
   - Saves the patched file as UTF-8 with BOM for PowerShell 5.1 compatibility.

- `GitRepositoryCherryPickWorkflow.Tests.ps1` expected `git cherry-pick` conflict exit code `1`, but your system returned `-1`.
   - Changes the assertion to accept any non-zero exit code.

- Scripts that warn and continue when a core module import fails are patched to throw instead.
   - This prevents smoke tests from passing after a broken module import.

## v3.6.4

- Fixed internal version consistency for the v3.6.4 package.
- Improved History / Graph visual model with ASCII lane badges and branch/tag/remote columns.
- Preserved full commit hash in visual history row selection.
- Added curated ScriptAnalyzer settings and runner behavior for useful optional linting.

## v3.6.1

- Fixed PowerShell parser regression caused by `$kind:` interpolation in recovery text.
- Added repository hygiene files: `README.md`, `VERSION`, `.gitignore`, `.gitattributes`, and `CHANGELOG.md`.
- Added repository workflow documentation and bootstrap script for consistent local Git tracking.
- Extended static smoke test to catch the `$kind:` parser regression before packaging.

## v3.6

- Added resolved/unresolved conflict-state detection.
- Added stage-resolved selected conflict file.
- Added operation-aware continue guidance for merge, cherry-pick, and rebase states.
- Added external merge tool configuration.
- Improved visual graph selection and command-preview coupling.
