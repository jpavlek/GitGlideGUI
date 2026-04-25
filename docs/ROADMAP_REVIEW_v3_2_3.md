# Git Glide GUI v3.5 Roadmap Review

## Implemented in this hotfix

- Fixed Pester 3.x compatibility in the quality-check runner.
- Kept invalid `LIB`, `INCLUDE`, and `LIBPATH` sanitization.
- Kept smoke-launch and static package checks as release gates.

## Still next

- History / Graph tab.
- History service extraction.
- Merge-aware history parsing tests.
- Conflict-resolution and cherry-pick workflows.

## Roadmap revision

No change required. This was a release-quality compatibility fix.

## v3.5 hotfix note

v3.5 does not change the feature roadmap. It improves release confidence by making the Pester quality gate compatible with Pester 3.x and by hardening branch/commit command-plan helpers that were exposed by the local Windows test run.
