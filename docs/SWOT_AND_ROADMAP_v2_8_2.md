# Git Glide GUI v2.8.2 - Hotfix SWOT and Roadmap Note

## Focus

v2.8.2 is a stabilization hotfix for issues found during real Windows testing of v2.8.1. It does not change the strategic roadmap.

## Strengths improved

- Startup intent selection is now more reliable and easier to understand.
- The startup dialog no longer contains a duplicate fourth continue button.
- Staging/diff previews are safer under strict mode with single changed files.

## Weaknesses addressed

- Previous startup-card event handling depended on fragile PowerShell closure behavior.
- The staging helper module assumed `.Count` was available even when PowerShell unrolled a one-item array into a scalar string.

## Remaining risks

- Live WinForms behavior still needs repeated Windows testing after each layout/event change.
- The monolithic GUI script still contains many legacy UI event paths.

## Roadmap impact

No roadmap reset is needed. v2.8.2 strengthens the same near-term direction:

1. Continue low-risk module extraction.
2. Add tests around extracted modules.
3. Improve beginner guidance and safe suggested actions.
4. Then implement larger visual features such as commit graph and conflict resolution UI.

## Recommended next iteration

Proceed with v2.9 after confirming v2.8.2 on Windows:

- Extract branch operations into `GitBranchOperations.psm1`.
- Add branch workflow tests.
- Improve dirty-working-tree guidance before switch, merge, and pull.
- Make more Suggested Next Action cases safely executable.
