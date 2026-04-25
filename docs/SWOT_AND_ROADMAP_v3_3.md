# Git Glide GUI v3.5 SWOT and Roadmap Notes

## Strengths added in v3.5

- Users can now inspect history and branch shape without leaving the GUI.
- The new history service continues the modular extraction strategy.
- Merge-commit parsing tests prepare the data model for a future visual graph.
- The graph feature is read-only, so it has low risk of causing repository damage.

## Remaining weaknesses

- The graph is textual, not yet a true interactive commit graph.
- There is still no visual conflict-resolution workflow.
- Cherry-pick and reflog recovery are still missing.
- The main WinForms script remains large, although more logic has moved into modules.

## Opportunities

- Turn parsed commit records into a real visual graph control.
- Add click-to-select commit details.
- Add cherry-pick planning from selected commits.
- Add conflict/recovery workflows using the same history model.

## Threats / risks

- Large repositories may produce slow history output if the max count is too high.
- Textual graph output is useful but less discoverable than a proper visual graph.
- More UI tabs can overwhelm beginners unless guidance remains clear.

## Recommended next step

v3.5 should start conflict-resolution and cherry-pick groundwork:

1. Extract conflict/status recovery helpers into a dedicated module.
2. Add a conflict guidance panel for merge, pull, stash pop/apply failures.
3. Add cherry-pick command planning and tests.
4. Continue toward a real visual graph control after the history model is stable.
