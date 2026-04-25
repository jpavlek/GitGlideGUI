# Git Glide GUI v3.5 - Pester 3 test-suite compatibility hotfix

## Problem fixed

v3.2.3 improved the Pester runner so Pester 3.x could start, but several tests still used assertion patterns that behave differently in Pester 3.4.0:

- `Should -Contain` was converted to `Should Contain`, which Pester 3 interprets as a file-content assertion instead of a collection-membership assertion.
- Some commit preview tests expected an unquoted `<temp-commit-message-file>` placeholder while the command preview quoted it.
- Two staging workflow tests built `$args` correctly but accidentally executed `git` without `@args`.
- One local-tag-delete test compared an empty command-output array to an empty string.

## Changes

- Updated the Pester 3 compatibility transformer to convert collection contains checks into explicit boolean checks.
- Changed commit command preview display so the placeholder remains readable as `<temp-commit-message-file>`.
- Fixed the staging workflow tests to execute generated command plans.
- Made the local-tag-delete test assert that the returned tag list is empty.
- Quoted stash references containing braces in preview text, e.g. `"stash@{0}"`.
- Added v3.5 release docs and static smoke markers.

## Recommended validation

From the package root or `scripts/windows` folder, run:

```bat
run-quality-checks.bat
```

Expected result on older Windows PowerShell/Pester 3.4.0 systems:

```text
Detected Pester 3.x. Creating compatibility test copy with legacy Should syntax.
Passed: ... Failed: 0
```
