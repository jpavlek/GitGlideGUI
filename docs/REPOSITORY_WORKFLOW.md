# Git Glide GUI Repository Workflow

## Goal

Git Glide GUI should be maintained as a normal Git repository, not only as versioned ZIP snapshots. This makes changes reviewable, preserves release history, and reduces regression risk.

## Recommended local setup

Use one stable development folder, for example:

```text
D:\Projects\PersonalCloud\GitFlowGUI\GitGlideGUI
```

Use versioned folders and ZIP files only for releases, for example:

```text
release\GitGlideGUI_v3_6_13_functional.zip
```

## Quality gate

Before every merge to `main`, release ZIP, or tag, run:

```bat
run-quality-checks.bat
```

The quality gate runs:

```text
static package smoke test
Windows smoke-launch parser/import test
Pester tests
PSScriptAnalyzer if installed
```

## Normal feature/fix workflow

```bat
git switch develop
git pull --ff-only
git switch -c feature/my-work

rem edit files
run-quality-checks.bat
git add -A
git commit -m "feat: describe the change"
git push -u origin HEAD

git switch develop
git merge --no-ff feature/my-work
run-quality-checks.bat
git push

git switch main
git merge --no-ff develop
git push
git tag -a v3.6.13 -m "Git Glide GUI v3.6.13"
git push origin --tags
```

## What Git Glide GUI helps with

Use **Integrate -> Merge & Publish** to:

- inspect branch tracking with `git branch -vv`,
- push a new branch with upstream using `git push -u origin HEAD`,
- sync `main -> develop`,
- merge a selected feature/fix branch into `develop`,
- run quality checks before promotion,
- promote `develop -> main`,
- open a detected GitHub pull-request URL,
- clean up a merged feature/fix branch after confirmation.

## v3.6.13 workflow checklist and branch cleanup

v3.6.13 adds an advisory checklist for the full promotion path:

```text
work on feature/fix branch
push branch with upstream
merge feature/fix into develop
run quality checks
promote develop into main
push and tag release
clean up merged branch
```

The cleanup workflow is intentionally separate and confirms before running:

```bat
git branch -d feature/my-work
git push origin --delete feature/my-work
```

Use cleanup only after the feature/fix branch was merged and pushed.

## v3.6.12 UI organization and progressive disclosure

- Adds Simple, Workflow, and Expert UI modes to reduce visual overload without removing functionality.
- Keeps the primary workflow visible while moving advanced actions into mode-aware tabs and the command palette.
- Improves the Changed Files context banner with mode, branch, branch role, upstream, state, changed count, and recommended next action.
- Keeps v3.6.11 branch-context and protected-branch workflow guard behavior intact.

## GitHub publish guidance

Use **Setup -> GitHub publish...** after local commits exist and you want to connect the project to GitHub. The workflow recommends a private GitHub repository for proprietary, client, security-sensitive, or unfinished work, helps build the remote URL, and reminds you to review GitHub Copilot AI/data-training settings where your plan allows opt-out.

## GitHub diagnostics

Use **Setup -> GitHub diagnostics...** to inspect remotes, upstream tracking, repository access, and push-with-upstream behavior.

Useful commands:

```bat
git remote -v
git branch --show-current
git push -u origin HEAD
git ls-remote --heads origin
```
