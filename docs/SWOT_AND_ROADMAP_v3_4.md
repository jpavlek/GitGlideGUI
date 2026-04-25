# Git Glide GUI v3.5 SWOT and Roadmap Update

## Strengths

- More workflows are now represented by testable modules rather than only the monolithic GUI script.
- Recovery guidance reduces anxiety after failed pull, merge, stash, and cherry-pick operations.
- Cherry-pick enters the product as command planning plus guarded execution rather than an unsafe one-click command.
- History / Graph and Recovery now support each other: inspect history first, then recover or cherry-pick deliberately.

## Weaknesses

- The graph is still textual, not a true visual graph control.
- Recovery guidance is rule-based and can still miss rare Git errors.
- The WinForms UI remains large and monolithic, although core workflow logic is increasingly modular.

## Opportunities

- Add a true visual graph control using the existing history model.
- Add conflict-file list and one-click open-in-editor integration.
- Add cherry-pick from selected history row instead of typed hash/ref only.
- Add guided merge-conflict resolution workflow.

## Threats

- Git recovery workflows can be dangerous if users do not understand abort/continue semantics.
- Large repositories may require more caching and pagination in future graph work.
- Mature Git clients already provide visual graph and conflict tools.

## Recommended next iteration

v3.5 should continue from the Recovery foundation:

1. Add a dedicated conflict-file list using `git diff --name-only --diff-filter=U`.
2. Add open-file/open-folder actions for conflicted files.
3. Add cherry-pick from History / Graph selection.
4. Start shaping the history model into a simple visual graph control.
