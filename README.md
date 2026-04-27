# Git Glide GUI v3.8.1

Git Glide GUI is a lightweight, privacy-first Windows Git interface built with PowerShell/WinForms and designed for both manual and AI-assisted software development.

Instead of hiding Git behind abstractions, Git Glide GUI focuses on transparency. It helps turn rapid coding changes into deliberate versioning decisions by making Git operations visible, explainable, and safer before they are executed. In fast-changing workflows, this lowers friction, shortens iteration time, and helps developers stay in control while applying their own judgment.

## Why this exists

Modern development can move very quickly, especially when AI-assisted coding produces many changes in a short time. Git remains the source of truth, but the decision points around staging, committing, branching, syncing, recovering, and publishing can become easy to rush or overlook.

Git Glide GUI exists to reduce that friction without removing developer responsibility. It makes Git operations easier to inspect before execution, supports safer recovery from risky repository states, and helps developers turn rapid code changes into intentional versioning steps.

The goal is not to replace Git knowledge, but to make Git workflows more transparent, faster to navigate, and easier to apply consistently.

## What makes it different?

Git Glide GUI is designed around decision safety, not only Git convenience.

It is not trying to be the most complete Git GUI. It is designed to be a transparent, safety-oriented Git workflow assistant for fast Windows-based manual and AI-assisted development.

Many Git tools focus on helping developers perform Git operations faster. Git Glide GUI focuses on the moments before execution: choosing what to stage, when to commit, which branch to use, whether a sync is safe, how to recover from a risky state, and when quality checks should run.

This makes it especially useful in fast manual and AI-assisted development workflows, where many code changes can appear quickly and the main risk is not typing Git commands, but rushing versioning decisions. It combines visual staging, command previews, branch-role guidance, recovery workflows, custom actions, history inspection, branch-relationship summaries, and quality checks into a lightweight Windows tool that keeps Git transparent and developer-controlled.

## Core Features

- ***Complete Git Toolset***: Supports everyday Git workflows, Git Flow-style branch management, visual staging, commits, stash operations, tags, history inspection, GitHub publishing, and custom actions.

- ***Safety First***: Preview commands before execution, run quality checks, inspect branch relationships, and rely on built-in recovery guidance for risky repository states.

- ***For Every Skill Level***: Onboarding learning sections help beginners understand the "why" behind actions, while reminders and custom actions help experienced users move quickly without losing transparency or control.

## Current focus: v3.8.1 version source-of-truth and release-churn reduction

v3.8.1 is a stabilization release. It reduces release churn by moving runtime launch paths from versioned script filenames to stable script filenames and treating the version as data.

The release focuses on three areas:

1. **Stable runtime entrypoint** — `git-glide-gui.bat` launches the stable PowerShell entrypoint instead of a versioned script filename.
2. **Version source-of-truth** — `VERSION` and `manifest.json` define the current product version, while runtime file names remain stable across releases.
3. **Lower release noise** — future versions should no longer need to rename the main GUI script and all six split-script parts only because the version number changed.

The goal is to make future releases easier to review, test, package, and merge by reducing version-only file churn.

## Previous focus: v3.8.0 visual history and branch understanding

v3.8.0 built on the v3.7 recovery, diff-visibility, and split-script foundation by making branch relationships easier to inspect before merge, pull, push, cleanup, or release decisions.

It added current branch vs upstream, current branch vs `develop`, and `develop` vs `main` relationship summaries with ahead/behind counts, merge-base inspection, and unique commit previews.

## Previous focus: v3.7.0 branch sync, conflict recovery, and technical-debt reduction

v3.7.0 improved Git Glide GUI as a safer workflow assistant for fast-moving manual and AI-assisted development.

It added repository state clarity, stronger conflict recovery UX, color-coded diff rendering, dynamic context banner sizing, and a split-script architecture that reduced the risk of maintaining one very large GUI script.

## Quick Start

```bat
git-glide-gui.bat
```

Optional repository path:

```bat
git-glide-gui.bat -RepositoryPath D:\Projects\YourRepo
```

## Quality gate

The quality gate runs:

1. Static package/version/line-count smoke test.
2. Windows smoke launch with `-SmokeTest`.
3. Pester tests when Pester is installed.
4. PSScriptAnalyzer checks when PSScriptAnalyzer is installed.

Run it from the repository root:

```bat
run-quality-checks.bat
```

## Stable split-script layout

The launcher calls the stable entrypoint:

```text
scripts/windows/GitGlideGUI.ps1
```

That entrypoint dot-sources the stable implementation parts:

```text
scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1
scripts/windows/GitGlideGUI.part02-state-selection.ps1
scripts/windows/GitGlideGUI.part03-previews-basic-ops.ps1
scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1
scripts/windows/GitGlideGUI.part05-ui.ps1
scripts/windows/GitGlideGUI.part06-run.ps1
```

The product version is read from `VERSION` and `manifest.json`. Runtime script filenames no longer need to change for every release.

## Repository tracking

This package is ready to be tracked as a dedicated Git repository.

See:

```text
docs/REPOSITORY_WORKFLOW.md
```

## Documentation

Start with:

```text
docs/START_HERE.md
docs/REPOSITORY_WORKFLOW.md
```

Release notes:

```text
docs/RELEASE_NOTES_v3_8_1.md
docs/RELEASE_NOTES_v3_8.md
```

v3.8 line architecture and planning:

```text
docs/ARCHITECTURE_v3_8.md
docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_8.md
docs/SWOT_AND_ROADMAP_v3_8.md
docs/ROADMAP_REVIEW_v3_8.md
```
