# Git Glide GUI v3.5 - Pester 3 Compatibility and Command Plan Hotfix

## Problem fixed

v3.2.2 improved the Pester runner so Pester 3.4.0 no longer failed on the ambiguous `-Output` parameter. Running the suite then exposed two more quality-check issues on Windows PowerShell + Pester 3:

1. Test files used newer Pester assertion operators such as `Should -Be`, `Should -Match`, and `Should -Throw`, while Pester 3 expects legacy syntax such as `Should Be`, `Should Match`, and `Should Throw`.
2. Several command-plan helpers used PowerShell forms that were too fragile under Windows PowerShell 5.1, especially generic lists passed as arrays and comma-separated expressions that could bind the comma to a string parameter.

## Changes

- `run-pester-tests.ps1` now detects Pester 3.x and creates a temporary compatibility copy of the test suite with legacy `Should` syntax.
- The compatibility copy includes the modules folder, so existing relative imports still work.
- Source tests remain readable and modern; the compatibility conversion happens only during local Pester 3 runs.
- `GitBranchOperations.psm1` now uses simpler array-based command-plan assembly.
- `GitCommitOperations.psm1` now uses simple string arrays for commit arguments instead of passing a generic list as one object.
- Soft-undo and merge command-plan builders now avoid comma placement that can be interpreted as part of a parameter value.

## Why this matters

This turns the quality-check suite into a practical compatibility gate for the environment currently used to test the app: Windows PowerShell 5.1 with Pester 3.4.0.

## Recommended test

From the package root or from `scripts\windows`:

```bat
run-quality-checks.bat
```

Expected behavior:

- static package smoke test passes
- Windows smoke-launch test passes
- Pester runner detects Pester 3.x when applicable
- tests run against the compatibility copy instead of failing on `Should -Be` syntax
