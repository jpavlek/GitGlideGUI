# Git Glide GUI v3.6.5 - SWOT and Roadmap

## Strengths added in v3.6.5

- Safer recovery workflow for merge, cherry-pick, and rebase conflicts.
- Clearer user feedback when conflict markers remain.
- Better protection against accidentally committing unresolved conflict text.
- More testable recovery helper logic in the core module.

## Weaknesses remaining

- Verification currently happens when staging one selected resolved file.
- Continue-operation verification should scan all resolved candidates in a future iteration.
- ScriptAnalyzer still reports style and legacy PowerShell warnings that should be triaged later.

## Opportunities

- Add full recovery readiness checks before continue/commit operations.
- Show a small conflict checklist in the Recovery tab.
- Offer one-click open around detected marker lines if editor integration is added later.

## Recommended v3.6.6

Implement pre-continue recovery verification across all candidate files. The Continue button should warn or block when any staged/resolved candidate still contains conflict markers.
