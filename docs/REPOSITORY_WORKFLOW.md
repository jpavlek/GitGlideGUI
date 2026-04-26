# Git Glide GUI Repository Workflow

## Goal

Git Glide GUI should now be maintained as its own repository instead of only as versioned ZIP snapshots. This reduces regression risk, makes changes reviewable, and creates a clearer release history.

## Recommended local setup

From the extracted package root:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\init-gitglide-repo.ps1
```

This initializes a local Git repository if needed, commits the current package, and tags it as `v3.6.6`.

## Manual equivalent

```bat
git init -b main
git add -A
git commit -m "chore: initialize Git Glide GUI repository at v3.6.6"
git tag -a v3.6.6 -m "Git Glide GUI v3.6.6"
```

If your Git version does not support `git init -b main`:

```bat
git init
git branch -M main
```

## Suggested release flow

```bat
git switch -c feature/v3-6-5-conflict-marker-verification
run-quality-checks.bat
git add -A
git commit -m "feat: implement conflict verification workflow"
git switch main
git merge --no-ff feature/v3-6-5-conflict-marker-verification
git tag -a v3.6.6 -m "Git Glide GUI v3.6.6"
```

## Remote setup

Create an empty repository on GitHub/GitLab/Bitbucket, then run:

```bat
git remote add origin <remote-url>
git push -u origin main
git push origin --tags
```

## Quality gate

Before every release ZIP or tag, run:

```bat
run-quality-checks.bat
```


## GitHub publish guidance

Use **Setup -> GitHub publish...** after you have local commits and want to connect the project to GitHub. The workflow recommends a private GitHub repository for proprietary, client, security-sensitive, or unfinished work, helps build the correct remote URL, and reminds you to review GitHub Copilot AI/data-training settings where your plan allows opt-out.


## v3.6.7 GitHub diagnostics and file removal

Use Setup -> GitHub diagnostics to inspect remotes, upstream tracking, repository access, and push-with-upstream. Use Stop tracking when a file should stay local but no longer be versioned, and Remove file only when it should be deleted from disk and staged as a deletion.

## v3.6.7.1 GitHub diagnostics hotfix

This release fixes the GitHub remote parser for Windows PowerShell 5.1 / Pester 3 compatibility while preserving the v3.6.7 GitHub diagnostics and safer file-removal workflows.

## Clean tracked file replacement

Changed Files lists changed paths only. To replace a clean tracked file, use **Browse tracked files**, select the file, then choose **Remove from Git and disk** or **Stop tracking, keep local**.


## v3.6.10.1: Feature -> develop -> main

Recommended sequence:

```bat
git branch -vv
git push -u origin HEAD
git switch develop
git merge main
git merge --no-ff <feature-branch>
scripts\windows\run-quality-checks.bat
git push -u origin develop
git switch main
git merge --no-ff develop
git push -u origin main
```

Git Glide GUI exposes this as a guided, previewable workflow in the Integrate tab.

## v3.6.10.1 workflow guard

Git Glide GUI warns before committing directly on `main` or `develop`. The warning is intentional but non-blocking: developers may continue when they are making a deliberate hotfix, release, or merge-resolution commit. For ordinary feature work, create a feature branch first, commit there, merge feature -> develop, run quality checks, and then merge develop -> main.


## v3.6.11 Branch context and workflow guard

- Shows branch role and recommended next step above Changed Files.
- Warns before staging or committing directly on protected branches.
- Offers a create-branch-first path so current changes can move to a feature/fix branch before commit.

## v3.6.12 UI organization and progressive disclosure

- Adds Simple, Workflow, and Expert UI modes to reduce visual overload without removing functionality.
- Keeps the primary workflow visible while moving advanced actions into mode-aware tabs and the command palette.
- Improves the Changed Files context banner with mode, branch, branch role, upstream, state, changed count, and recommended next action.
- Keeps v3.6.11 branch-context and protected-branch workflow guard behavior intact.
