# Git Glide GUI v2.9 SWOT and Roadmap Update

## SWOT update

### Strengths

- Branch workflow logic is now partially extracted from the monolithic GUI into `GitBranchOperations.psm1`.
- Risky branch workflows have clearer pre-operation guidance.
- Pulls are safer by default through `git pull --ff-only` in generated branch plans.
- Suggested Next Action is becoming more useful because ahead/behind branch states can now trigger guarded actions.

### Weaknesses

- The WinForms GUI is still mostly monolithic.
- Branch extraction is not yet complete; lower-level execution still lives in the main script.
- No live automated Windows GUI smoke test is included yet.
- Visual graph and conflict-resolution UI are still missing.

### Opportunities

- Extract stash and tag/release operations next, following the same pattern.
- Add Windows CI with Pester, PSScriptAnalyzer, and a smoke-launch test.
- Convert more suggestions into explicit, confirmable workflows.
- Use the branch module as groundwork for future graph, rebase, cherry-pick, and branch cleanup features.

### Threats

- Regressions can still occur in UI event handling because the main script is large.
- Remote-affecting actions such as push/pull need careful confirmations and wording to preserve trust.
- Large visual features could destabilize the app if implemented before enough logic is extracted and tested.

## Roadmap position after v2.9

### Implemented in v2.9

- Extract branch operation planning.
- Add branch module tests.
- Add temporary-repository branch workflow tests.
- Improve dirty-working-tree guidance before switch, merge, and pull.
- Make more Suggested Next Action states executable with guardrails.

### Recommended next iteration: v2.10

1. Extract stash operation planning into `GitStashOperations.psm1`.
2. Add temporary-repository stash workflow tests.
3. Improve conflict/recovery guidance after stash pop/apply failures.
4. Add safe Suggested Next Action cases for stashing dirty work.
5. Start a minimal Windows smoke-test script that can launch and close the GUI.

## Roadmap revision

No major roadmap rewrite is needed. The current revised roadmap remains valid: continue service/module extraction and test coverage before large visual features. v2.9 confirms that this path is working.
