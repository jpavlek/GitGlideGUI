# Git Glide GUI v3.6.6

Git Glide GUI is a Windows PowerShell/WinForms Git helper focused on safer visual Git workflows, onboarding, staging, branching, stash recovery, tags/releases, commit guidance, and guided next actions.

## Start the app

From the extracted package root:

```bat
git-glide-gui.bat
```

To open a specific repository:

```bat
git-glide-gui.bat -RepositoryPath "D:\Projects\PersonalCloud\PersonalCloud_v33_3_9"
```

The old compatibility launcher is still included:

```bat
git-flow-gui2.bat
```

## First startup choices

- **Open existing repo**: choose a folder that already has `.git`.
- **Init new repo**: choose a normal folder and create a new Git repository there.
- **Continue without repo**: open the app without selecting a repository yet.

## Quality checks

From the extracted package root:

```bat
run-quality-checks.bat
```

or directly:

```bat
scripts\windows\run-quality-checks.bat
```

For Pester only:

```bat
run-pester-tests.bat
```

For the parser/import smoke check only:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
```

If you are already inside `scripts\windows`, use:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File smoke-launch.ps1
```

## v3.6 focus

v3.6 keeps the v3.2 commit-operation extraction and adds a shutdown-stability hotfix for a WinForms `PipelineStoppedException` / JIT debugging dialog that could appear when closing the app.


## v3.6 History / Graph

Use the **History / Graph** tab to inspect a read-only `git log --graph` view before merging, pulling, deleting tags, or undoing commits.


Roadmap update: see `docs/ANALYSIS_AND_ROADMAP_v3_6.md`.

## v3.6.1 repository tracking

To start tracking Git Glide GUI consistently as its own repository, run:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\init-gitglide-repo.ps1
```

See `docs/REPOSITORY_WORKFLOW.md`.

## v3.6.4 History / Graph polish

v3.6.4 improves the visual history table with ASCII graph badges and explicit branch, tag, and remote columns. The table remains read-only and keeps the full commit hash internally when a row is selected for show/cherry-pick previews.


## v3.6.4 Stability and first-commit workflow fix

v3.6.4 improves the first-commit path. If you stage a file before the repository has a first commit, **Unstage selected** now uses `git rm --cached -- <file>` instead of `git restore --staged -- <file>`, because `git restore --staged` requires `HEAD`. It also removes a fragile splitter event handler that could show a WinForms JIT dialog during resize or shutdown.


## v3.6.6 Conflict marker verification

v3.6.6 improves Recovery safety. Before **Stage resolved file** runs `git add -- <file>`, Git Glide scans the selected file for a complete Git conflict marker block using `<<<<<<<`, `=======`, and `>>>>>>>`. If markers remain, staging is blocked and the user is told which marker lines need attention. This lowers the risk of accidentally committing unresolved conflict text.


## GitHub publish guidance

Use **Setup -> GitHub publish...** after you have local commits and want to connect the project to GitHub. The workflow recommends a private GitHub repository for proprietary, client, security-sensitive, or unfinished work, helps build the correct remote URL, and reminds you to review GitHub Copilot AI/data-training settings where your plan allows opt-out.


## v3.6.7 GitHub diagnostics and file removal

Use Setup -> GitHub diagnostics to inspect remotes, upstream tracking, repository access, and push-with-upstream. Use Stop tracking when a file should stay local but no longer be versioned, and Remove file only when it should be deleted from disk and staged as a deletion.

## v3.6.7.1 GitHub diagnostics hotfix

This release fixes the GitHub remote parser for Windows PowerShell 5.1 / Pester 3 compatibility while preserving the v3.6.7 GitHub diagnostics and safer file-removal workflows.

## v3.6.8 tracked-file browsing

Use **Stage -> Browse tracked files** when a committed file is clean and therefore not visible in Changed Files, but you still need to remove it from Git or stop tracking it before replacement.


## v3.6.10: Merge & Publish

Use **Integrate -> Merge & Publish** to inspect branch tracking, push a new branch with upstream, sync `main -> develop`, merge a selected feature branch into `develop`, run quality checks, and promote `develop -> main`.
