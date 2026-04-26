# Roadmap After v3.7

## v3.8 — Visual History and Branch Graph

Recommended next step:

- Promote text-based `git log --graph` preview into a structured history panel.
- Add branch filters.
- Add selected-commit details.
- Add safe copy commands for commit hash and branch name.
- Add cherry-pick preview without automatic execution.

## v3.9 — Merge Conflict Assistant

Recommended next step:

- Show conflicted files with marker counts.
- Open conflict blocks directly by line number.
- Offer ours/theirs/base comparison commands.
- Keep actual resolution manual unless a safe strategy is explicitly selected.

## v4.0 — Modularization

Recommended larger architectural step:

- Extract Git command execution into a service module.
- Extract UI helpers into a UI module.
- Add Pester tests for non-UI functions.
- Preserve a single-file release build for easy distribution.
