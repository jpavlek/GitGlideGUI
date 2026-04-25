# Git Glide GUI v2.8 SWOT and Roadmap

## SWOT update

### Strengths

- Clearer onboarding path for three common intentions: open existing, initialize new, or inspect without a repository.
- Safer guided workflow through clickable suggestions that avoid surprise destructive Git operations.
- Beginner / Advanced mode reduces first-run cognitive load while preserving power-user workflows.
- Onboarding logic is now partially extracted into a UI-free module, making it easier to test and evolve.
- Broader temporary-repository tests cover the workflows most likely to damage user trust if broken.

### Weaknesses

- The main GUI is still largely monolithic.
- WinForms layout remains functional rather than modern.
- Beginner / Advanced mode currently hides whole tabs rather than adapting each workflow in detail.
- Suggested actions are intentionally conservative; not every suggestion is executable.
- Pester and ScriptAnalyzer are optional and must be installed by the user/developer.

### Opportunities

- Convert more UI logic into modules: repository onboarding, status, staging, stash, tags, and branch workflows.
- Add guided first-use tutorial overlays.
- Add more context-aware suggested actions once integration tests cover those paths.
- Add visual branch graph and safer conflict-resolution UX after core behavior is test-covered.
- Package as a signed release or installer once the startup and onboarding experience stabilizes.

### Threats

- Larger UI features may destabilize the tool if implemented before enough automated coverage exists.
- Competing Git GUIs offer richer visual graphs and merge tools.
- PowerShell/WinForms limits cross-platform adoption.
- Git behavior differs across versions, especially around `git init -b` and default branch naming.

## Priority roadmap

### v2.8 recommended next

1. Extract staging and changed-file operations into a testable module.
2. Add integration tests for stage selected, unstage selected, stage all, and diff preview command planning.
3. Improve Beginner mode with plain-language descriptions inside each visible tab.
4. Add a lightweight visual branch graph using existing `git log --graph` output before attempting a custom graph renderer.

### v2.9

1. Extract tag/release operations into a module.
2. Add safer release-tag wizard.
3. Add branch-create and branch-switch integration tests.
4. Add optional commit-message templates per workflow.

### v3.0 candidate

1. Modularize Git services enough that the WinForms UI becomes a shell over tested workflows.
2. Add installer/release packaging.
3. Add signed scripts or documented execution-policy options.
4. Evaluate whether the project should remain PowerShell/WinForms or evolve toward a cross-platform UI.
