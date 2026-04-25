# Git Glide GUI v2.8.1 - Hotfix SWOT and Roadmap Note

## SWOT delta from v2.8

### Strengths

- Real user feedback was converted into a targeted hotfix quickly.
- The startup onboarding dialog now avoids fragile nested event-handler scope assumptions.
- The dialog layout is more tolerant of DPI, scaling, and translated or longer explanatory text.

### Weaknesses

- The main GUI is still a large WinForms/PowerShell script, so UI regressions remain possible without live Windows UI tests.
- Static tests catch known markers and obvious regressions, but cannot prove every WinForms event path works.

### Opportunities

- Add a small Windows smoke-test script that opens and closes key dialogs automatically.
- Continue extracting UI-free modules so more behavior can be tested without launching WinForms.
- Use this defect as a pattern: avoid nested UI handlers that depend on ambiguous local variable resolution.

### Threats

- More UI event handlers may hide similar scoping issues.
- Larger visual features such as graph or conflict resolution should not be started until basic dialog reliability improves.

## Roadmap impact

The roadmap does not need a strategic rewrite, but v2.9 should include a short stabilization task before branch-operation extraction:

1. Audit important dialog event handlers for closure/scope risk.
2. Add Windows smoke-test coverage for startup choices.
3. Then continue with `GitBranchOperations.psm1`, dirty-working-tree guidance, and branch workflow tests.
