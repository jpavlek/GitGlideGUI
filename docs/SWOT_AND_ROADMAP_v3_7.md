# SWOT and Roadmap v3.7.0

## Strengths

- The full repo structure is preserved: modules, tests, scripts, and documentation remain part of the solution.
- The GUI no longer depends on a single 8k+ line version script.
- Repository State Doctor directly addresses real workflow problems observed during v3.6.13 merging: detached HEAD, divergence, unresolved conflicts, conflict markers, and accidental untracked files.
- Quality checks now enforce version consistency and a 4000-line implementation-file guard.

## Weaknesses

- The split files are still dot-sourced script parts, not yet clean UI classes or independent modules.
- Some UI behavior remains tightly coupled to global `$script:` state.
- Repository State Doctor is still partly UI-script logic; the pure decision model should move into a core module in v3.7.1.

## Opportunities

- Extract state-doctor logic into `GitRepositoryStateDoctor.psm1` with Pester tests.
- Convert large UI regions into composable panel builders.
- Build a safer visual branch/history graph in v3.8.
- Build a guided conflict-resolution assistant in v3.9.

## Threats

- Too much refactoring in one release could break working Git workflows.
- PowerShell WinForms layout changes are sensitive to DPI and parent container behavior.
- Test warnings can hide real issues if quality gates are not made stricter gradually.

## Adjusted roadmap

1. v3.7.0: split-script architecture, state doctor, marker scanner, quality gates.
2. v3.7.1: extract state doctor into a pure core module and add Pester tests.
3. v3.7.2: extract UI panel builders for Recovery, History, and Changed Files.
4. v3.8.0: visual history graph and branch relationship improvements.
5. v3.9.0: guided conflict-resolution assistant.
