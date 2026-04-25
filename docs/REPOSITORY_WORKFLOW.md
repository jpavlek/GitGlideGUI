# Git Glide GUI Repository Workflow

## Goal

Git Glide GUI should now be maintained as its own repository instead of only as versioned ZIP snapshots. This reduces regression risk, makes changes reviewable, and creates a clearer release history.

## Recommended local setup

From the extracted package root:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\init-gitglide-repo.ps1
```

This initializes a local Git repository if needed, commits the current package, and tags it as `v3.6.5`.

## Manual equivalent

```bat
git init -b main
git add -A
git commit -m "chore: initialize Git Glide GUI repository at v3.6.5"
git tag -a v3.6.5 -m "Git Glide GUI v3.6.5"
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
git tag -a v3.6.5 -m "Git Glide GUI v3.6.5"
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
