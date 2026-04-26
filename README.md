# Git Glide GUI

Git Glide GUI is a lightweight Windows PowerShell/WinForms Git companion focused on safer visual Git workflows, onboarding, branch/stash/tag/commit operations, history inspection, and recovery guidance.

## Quick start

```bat
git-glide-gui.bat
```

Or start with a repository path:

```bat
git-glide-gui.bat -RepositoryPath "D:\Projects\PersonalCloud\PersonalCloud_v33_3_9"
```

## Quality checks

```bat
run-quality-checks.bat
```

## Repository tracking

This package is ready to be tracked as a dedicated Git repository. See `docs/REPOSITORY_WORKFLOW.md`.


## v3.6.10.1 Merge & Publish workflow

The Integrate tab now includes branch tracking, push-with-upstream, `main -> develop` sync, selected feature merge into `develop`, quality checks, and `develop -> main` promotion.


## v3.6.11 Branch context and workflow guard

- Shows branch role and recommended next step above Changed Files.
- Warns before staging or committing directly on protected branches.
- Offers a create-branch-first path so current changes can move to a feature/fix branch before commit.
