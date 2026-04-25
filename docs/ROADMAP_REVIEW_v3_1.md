# Git Glide GUI Roadmap Review v3.1

## Implemented from the roadmap

The original roadmap identified the need to reduce monolithic architecture, introduce tests, improve safety, and add missing Git features. v3.1 continues that direction.

Implemented so far:

```text
security hardening
custom command safety
audit logging
soft undo last commit
repository detection
open existing repo
init new repo
first commit wizard
.gitignore templates
remote setup
suggested next action
clickable safe suggested actions
beginner / advanced mode
staging operation extraction
branch operation extraction
stash operation extraction
tag / release operation extraction
static smoke tests
temporary Git repository tests
minimal Windows smoke-launch check
mandatory smoke-launch packaging gate
```

## Implemented outside the original roadmap

These emerged from real feedback and should remain in the revised roadmap:

```text
renaming from GitFlowGUI to Git Glide GUI
backward-compatible launcher
startup choice cards
handling extracted-tool-folder launch case
init-new-repo onboarding path
first commit wizard
.gitignore workflow
remote setup workflow
safe suggested stashing
mandatory package-release gate
```

## Still pending

```text
commit operation extraction
visual commit / branch graph
visual merge conflict resolution
interactive rebase helper
cherry-pick workflow
reflog recovery UI
worktree support
file history / blame view
GitHub / GitLab PR integration
CI/CD pipeline
accessibility pass
```

## Roadmap revision

The roadmap should now explicitly include a packaging/release-quality lane:

```text
Every release candidate must pass:
1. static package smoke test
2. Windows smoke-launch parser/import test
3. Pester tests where available
4. ScriptAnalyzer checks where available
```

The next logical technical step is commit-operation extraction before visual graph work, because the graph and history tooling need clean commit models.
