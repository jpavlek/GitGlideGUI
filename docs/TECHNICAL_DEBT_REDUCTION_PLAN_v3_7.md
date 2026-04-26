# Technical Debt Reduction Plan v3.7+

## Completed in v3.7.0

- Replaced one 8k+ line versioned GUI script with a split-script architecture.
- Added static guard against implementation files larger than 4000 lines.
- Preserved the full repository structure, including modules, tests, and documentation.
- Added state-doctor and conflict-marker recovery UX without rewriting existing Git operation semantics.

## v3.7.1 recommendation

Extract pure repository-state analysis into:

```text
modules/GitGlideGUI.Core/GitRepositoryStateDoctor.psm1
tests/GitRepositoryStateDoctor.Tests.ps1
```

Keep the UI functions in the GUI script parts, but make the decision model testable.

## v3.7.2 recommendation

Extract Recovery, History, and Changed Files UI builders into separate UI script files. Do not change behavior at the same time.

## v3.8 recommendation

Improve branch/history visualization and make the text graph easier to inspect.

## v3.9 recommendation

Build a guided conflict-resolution assistant on top of the state doctor and marker scanner.
