# Git Glide GUI v2.8 Roadmap Review

## Implemented from the roadmap

### P0 / foundation

- Startup crash and splitter safety carried forward from earlier v1.8 work.
- Repository detection and clear handling when no Git repository is selected.
- New repository initialization flow.
- Safer destructive operation confirmation patterns.
- Soft undo last commit.
- Audit logging for Git command execution.
- Command safety parsing and allowlist module.

### P1 / usability and trust

- Product renamed from GitFlowGUI / Git Flow GUI to Git Glide GUI.
- Backward-compatible old launcher retained.
- Suggested Next Action panel added.
- Suggested Next Action is clickable for safe/navigation/wizard cases.
- Beginner / Advanced mode added.
- Startup choice cards and better initial-choice wording added.
- First Commit wizard added.
- `.gitignore` templates added.
- Remote setup workflow added.
- Tag / Release management added.
- Beginner guidance labels added in v2.8.

### P1 / quality

- Static package smoke tests added.
- Pester-style tests added for command safety.
- Temporary-repository integration tests added for status, initialization, onboarding, first commit, stash, tags, and staging.
- UI-free modules created for:
  - `GitCommandSafety.psm1`
  - `GitRepositoryStatus.psm1`
  - `GitRepositoryOnboarding.psm1`
  - `GitStagingOperations.psm1`

### P2 / architecture evolution

- Partial service extraction is underway.
- The app still uses the monolithic script as the stable shell, but core logic is being moved into testable modules.

## Still to do from the roadmap

### High priority

- Visual commit / branch graph.
- Visual merge conflict resolution.
- Interactive rebase helper.
- Cherry-pick workflow.
- More complete undo / recovery workflows using reflog.
- Branch-operation module extraction.
- Stash-operation module extraction.
- Tag-operation module extraction.
- Real Windows UI smoke tests.
- PSScriptAnalyzer integration in a repeatable CI pipeline.

### Medium priority

- Plugin / extension system.
- Multi-repository workspace.
- File history and blame views.
- Git worktree support.
- Submodule support.
- Git LFS support.
- Pull request integration.
- Issue tracker integration.

### Longer term

- Cross-platform version.
- Installer / update mechanism.
- Enterprise policy configuration.
- Accessibility pass.
- Localization.

## Implemented outside the original roadmap

These were not strongly emphasized in the original roadmap but proved valuable during real use:

- Product renaming to Git Glide GUI.
- Explicit handling of launching from the extracted tool folder.
- Intention-based startup choices:
  - Open existing repo
  - Init new repo
  - Continue without repo
- First Commit wizard.
- `.gitignore` template workflow.
- Remote setup workflow.
- Beginner guidance directly inside action tabs.
- Backward-compatible launcher transition strategy.

## Does the roadmap need revising?

Yes, slightly.

The original roadmap correctly identified architecture, testing, safety, visual graph, merge/conflict support, and integrations as important. However, the real user feedback showed that onboarding and repository-intent handling deserved higher priority than originally assumed.

## Revised roadmap recommendation

### Near-term sequence

1. Continue low-risk module extraction.
2. Add tests around each extracted module.
3. Improve beginner guidance and safe suggested actions.
4. Only then implement larger visual features.

### Recommended next version: v2.9

- Extract branch operations into `GitBranchOperations.psm1`.
- Add branch workflow tests.
- Improve Suggested Next Action with more safe branch-oriented actions.
- Add better dirty-working-tree guidance before switch/merge/pull.

### Recommended v3.0 milestone

- Consolidate documentation.
- Stabilize Git Glide GUI naming fully.
- Add first visual branch/commit graph prototype.
- Add stronger recovery/undo UX.

## Strategic conclusion

The roadmap remains valid, but the order should stay pragmatic: stability, onboarding, testability, and modularity first; visual graph and merge tooling after the command foundation is safer and better tested.
