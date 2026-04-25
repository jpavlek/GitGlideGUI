# Changelog

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

## v3.6.4

- Removed a fragile PowerShell `SplitterMoved` event handler that could trigger a WinForms JIT dialog during resize/shutdown.
- Fixed unstaging before the first commit by using `git rm --cached -- <file>` when `HEAD` does not exist.
- Added staging tests for the no-HEAD/unborn-repository workflow.

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
