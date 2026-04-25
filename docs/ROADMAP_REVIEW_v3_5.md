# Git Glide GUI Roadmap Review after v3.5

## Implementation progress by area

| Area | Approx. completion | Status |
|---|---:|---|
| Foundation stability and startup safety | 85% | Mostly implemented; continued Windows feedback still needed. |
| Repository onboarding | 90% | Open existing, init new, first commit, gitignore, and remote setup are implemented. |
| Command safety and destructive-operation guardrails | 75% | Custom command safety, confirmations, and recovery guidance exist; more command-specific policies can still be added. |
| Modular architecture extraction | 65% | Core Git workflow logic is now split into modules, but the WinForms UI remains monolithic. |
| Automated quality checks | 70% | Static smoke, Windows smoke launch, Pester compatibility, and package gate exist; CI is still missing. |
| Staging / commit / branch / stash / tag workflows | 75% | Major workflows have modules and tests; advanced edge cases remain. |
| History / graph | 35% | Read-only graph text and simple visual list exist; true visual graph control is still pending. |
| Conflict recovery | 45% | Guidance, conflict file list, open file/folder actions, and abort/continue commands exist; guided resolve/stage/continue remains pending. |
| Beginner education and workflow guidance | 55% | Learning tab exists; contextual inline explanations can be expanded. |
| Integrations: GitHub/GitLab/Jira/CI | 5% | Still mostly not started. |
| Cross-platform / installer / enterprise deployment | 10% | Still Windows zip based; packaging gate exists. |

## Implemented from the original roadmap

Approximate total roadmap completion: **55%**.

Implemented or mostly implemented:

- security hardening and custom-command safety
- audit logging
- startup stability and repository selection
- open existing repository
- initialize new repository
- first-commit onboarding
- `.gitignore` templates
- remote setup
- suggested next action
- clickable safe suggested actions
- Beginner / Advanced mode
- tag / release operations
- soft undo last commit
- staging, branch, stash, tag, commit, history, recovery and cherry-pick modules
- temporary-repository workflow tests
- Pester 3 compatibility fixes
- Windows smoke-launch gate
- read-only History / Graph tab
- first simple visual graph/list
- conflict-file list and open-file/open-folder actions

## Still to do from the original roadmap

Approximate remaining roadmap: **45%**.

Important pending items:

- richer visual commit graph
- guided merge conflict resolution
- file history and blame view
- interactive rebase helper
- worktree support
- submodule and Git LFS workflows
- reflog recovery UI
- GitHub/GitLab PR integration
- CI/CD status display
- Jira/ticket integration
- plugin system
- installer/update mechanism
- CI pipeline for packaging and tests
- accessibility pass and keyboard-navigation guide

## Implemented outside the original roadmap

Approximate extra-roadmap value delivered: **25%** relative to the current product scope.

Notable additions that emerged from real feedback:

- rename from GitFlowGUI to Git Glide GUI
- backward-compatible launcher transition
- explicit startup intent choices
- handling launch from the extracted package folder
- init-new-repository workflow
- first-commit wizard
- Pester 3 compatibility layer
- invalid LIB/INCLUDE/LIBPATH sanitization for local test reliability
- Learning tab with beginner explanations
- typical Git workflow guidance
- conflict-file open-file/open-folder actions
- simple visual history list before a full visual graph

## Does the roadmap need revising?

Yes. The direction is still correct, but priorities should be revised.

### Revised priority assessment

| Priority | Original emphasis | Revised emphasis |
|---|---|---|
| P0 | Stability/security | Still correct; keep regression fixes fast. |
| P1 | Visual graph / conflict UI | Split into smaller steps: read-only graph, conflict file list, guided resolution. |
| P1 | Tests | Increase priority because user feedback proved tests catch packaging regressions. |
| P2 | Modularization | Promote to P1 because it reduces regression risk. |
| P2 | Integrations | Keep later until local workflows are stable. |
| P3 | Education/help | Promote to P1/P2 because novice users are a core adoption target. |

## Recommended v3.6

1. Add resolved/unresolved conflict-state detection.
2. Add stage-resolved selected conflict file.
3. Add continue-operation guidance based on MERGE_HEAD / CHERRY_PICK_HEAD / REBASE_HEAD.
4. Add external merge tool launch configuration.
5. Improve visual graph selection and command preview coupling.
