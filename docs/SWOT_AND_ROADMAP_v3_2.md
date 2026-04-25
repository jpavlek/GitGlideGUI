# Git Glide GUI v3.2 - SWOT and Roadmap Update

## Strengths

- The product now has testable modules for command safety, repository status, onboarding, staging, branch, stash, tag/release, and commit workflows.
- The command preview model remains a major trust feature.
- The Windows smoke-launch gate reduces the risk of shipping parser/import regressions.
- Beginner onboarding and repository initialization are now part of the product instead of an afterthought.
- Commit operations now have a path toward Conventional Commits guidance and future graph/history features.

## Weaknesses

- The main WinForms script is still large and should continue to shrink gradually.
- Windows-only WinForms remains a platform limitation.
- There is still no visual commit graph, conflict resolver, or interactive rebase helper.
- Pester/ScriptAnalyzer tooling depends on the user's local PowerShell environment.
- Some workflows still execute directly from the GUI instead of through extracted modules.

## Opportunities

- Build the visual graph from the new compact commit/history model.
- Add commit templates and Conventional Commits validation as team policy options.
- Continue extracting modules until the GUI becomes mostly orchestration and presentation.
- Add reusable dry-run planning for more operations.
- Add CI on Windows once the project is put into a repository.

## Threats

- Mature Git GUI competitors already offer visual graph and conflict tools.
- PowerShell 5.1/Pester 3 environments can behave differently on developer machines.
- Unchecked feature growth could make the UI crowded again.
- Without regular Windows smoke tests, WinForms regressions can still slip through.

## v3.2 roadmap position

v3.2 completes another architecture/refactoring step while adding visible commit-message guidance. It is still part of the foundation phase, but it also prepares the future visual graph by introducing a compact commit/history model.

## Recommended v3.5

1. Extract a minimal history/graph service into `GitHistoryOperations.psm1` or extend the commit module if kept small.
2. Add a first read-only commit graph/history tab using `git log --graph --decorate --oneline --all` plus parsed model data.
3. Add tests for history parsing with merge commits.
4. Begin commit-operation UI simplification for Beginner mode.
