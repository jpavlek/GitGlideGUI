# Git Glide GUI v3.6.13 Roadmap Review

## Completed in this iteration

- Added an advisory Merge & Publish checklist.
- Added merged feature/fix branch cleanup guidance.
- Added release/version consistency checks to static smoke.
- Updated README and repository workflow documentation.

## Voting result summary

The highest voted priority was workflow continuity: make the expected feature/fix -> develop -> quality checks -> main sequence visible and hard to skip unintentionally. The second priority was release trust: stop version/package drift from reaching a release ZIP.

## Updated roadmap

### P0: Workflow trust and release consistency

- Keep branch context visible near Changed Files.
- Keep protected branch workflow guards.
- Keep static smoke version/package consistency checks.
- Make release ZIPs validate from a fresh extraction.

### P1: Guided workflow completion

- Expand the Merge & Publish checklist from preview text into a stateful checklist panel.
- Track the last quality-check result by branch and commit.
- Surface GitHub PR URLs directly in the workflow checklist.
- Add merged branch cleanup status: local exists, remote exists, merged into develop/main.

### P2: UI simplification and modularity

- Continue moving UI behavior from the main script into testable modules.
- Add a real command palette search/filter experience.
- Add pinned actions or favorites.
- Persist UI mode and panel collapse state.

### P3: Optional ecosystem integrations

- Optional GitHub CLI support for private repository creation and PR creation.
- Optional issue/ticket reference extraction.
- Optional local-first AI workflow hooks that do not send code anywhere by default.

## Next recommended iteration

v3.6.14 should focus on a stateful checklist panel and quality-check result memory:

- show checklist statuses instead of only preview text,
- record last quality-check pass/fail with branch and commit,
- warn before promoting develop -> main if quality checks were not run on the current commit.
