# Git Glide GUI v3.6.4 Release Notes

v3.6.4 is a focused history/graph polish and release-hygiene iteration.

## Added

- ASCII-safe visual graph lane badges for Windows PowerShell 5.1 robustness:
  - `H*` = HEAD/current branch tip
  - `B*` = local branch tip
  - `R*` = remote-tracking branch tip
  - `T*` = tag/release point
  - `M*` = merge commit
  - `HM` = merge commit at HEAD
- Richer parsed history model with branch, remote, tag, HEAD, and ref-kind classification.
- History / Graph table columns for Branches, Tags, Remotes, Author, and Date.
- Full commit hash retained in visual history row selection while the table still shows a short hash.
- Curated ScriptAnalyzer runner that suppresses style-only noise by default and keeps strict mode available.

## Fixed

- v3.6.2 package-name/internal-version mismatch from the manual hotfix process.
- History lane markers no longer require Unicode graph characters in the parsed model.

## Validation target

Run from `scripts/windows`:

```bat
run-quality-checks.bat
```

Expected functional gate:

```text
Static package smoke test passed.
Windows smoke-launch test passed.
Passed: 95 Failed: 0
Quality checks completed.
```

ScriptAnalyzer warnings remain non-blocking unless strict/fail-on-warning mode is requested.
