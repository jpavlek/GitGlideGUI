# Git Glide GUI v2.8 SWOT and Roadmap

## SWOT summary

### Strengths

- Functional PowerShell/WinForms Git client that remains easy to distribute.
- Product naming is now stronger: Git Glide GUI is more brandable than the generic Git Flow GUI name.
- Repository onboarding is much clearer than earlier versions.
- Suggested Next Action is now clickable for safe cases.
- Beginner / Advanced mode reduces initial UI overload.
- Core logic is increasingly testable through modules:
  - command safety
  - repository status
  - repository onboarding
  - staging / changed-file command planning

### Weaknesses

- The main GUI script is still monolithic and large.
- Live automated UI testing is still missing.
- The visual Git graph is text-based rather than an interactive graph.
- Conflict resolution is still not visual.
- Documentation is improving but still needs a consolidated user manual.

### Opportunities

- Continue extracting services without rewriting the working app.
- Build a richer beginner experience around task-based workflows.
- Add safe one-click actions from Suggested Next Action.
- Add visual branch graph and commit relationship view.
- Add GitHub/GitLab/Jira integrations later.
- Use command-plan modules as a foundation for future AI/hybrid workflow guidance.

### Threats

- Mature tools such as SourceTree, GitKraken, GitHub Desktop, and IDE-integrated Git remain strong competitors.
- PowerShell/WinForms limits cross-platform adoption.
- A large monolithic UI script can regress if refactoring is too aggressive.
- Git operations can cause data loss if confirmations and previews are weakened.

## Roadmap after v2.8

### v2.9 recommended priority

- Extract branch operations into `GitBranchOperations.psm1`.
- Add branch integration tests:
  - create feature branch
  - switch branch with clean tree
  - reject/safely guide dirty-tree switch
  - push-current-branch preview generation
- Make more Suggested Next Actions executable for safe cases.

### v3.0 recommended milestone

- Consolidated documentation and user manual.
- First visual commit/branch graph prototype.
- Stronger recovery UX around reflog and undo operations.
- Stable public package naming as Git Glide GUI.

### Later priorities

- Visual merge/conflict support.
- Cherry-pick workflow.
- Interactive rebase helper.
- Git worktree support.
- GitHub/GitLab pull-request integration.
- Optional telemetry only if transparent, local-first, and opt-in.
