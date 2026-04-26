# Git Glide GUI v3.6.12

Git Glide GUI is a lightweight, privacy-first Windows Git interface for safer human and AI-assisted software development. 
It turns fast coding changes into clear versioning choices, helping developers stay in control and use their judgment with command previews, visual staging, recovery guidance, custom actions, and quality checks.

v3.6.12 focuses on UI organization and progressive disclosure.
It adds Simple, Workflow, and Expert modes so everyday Git work stays visible while advanced tools remain available through mode-aware tabs and the command palette.

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

## UI modes

Use the mode selector to reduce visual overload without losing functionality.

- **Simple mode**: everyday Git work such as status, staging, commit, push, branch switching, stash, and refresh.
- **Workflow mode**: guided Git Flow work such as feature/fix branches, merge and publish, recovery, history, tags, and quality checks.
- **Expert mode**: all tools, including custom Git commands, diagnostics, advanced actions, appearance, and release helpers.

Use **Command palette...** to find less common actions without keeping every button visible at once.

## Branch context and workflow guard

Git Glide GUI shows the current branch context above **Changed Files**, including mode, branch, branch role, upstream, repository state, changed count, and recommended next action.

Branch roles are used to guide workflow decisions:

- `main`: protected release branch.
- `develop`: integration branch.
- `feature/*`: feature branch.
- `fix/*`: fix branch.
- `hotfix/*`: urgent release fix branch.
- `release/*`: release preparation branch.

If you try to stage or commit normal work directly on `main` or `develop`, Git Glide GUI warns you and offers a safer path. The warning is advisory, not a hard block. You can still continue intentionally for hotfixes, release commits, or special cases.

Recommended normal workflow:

1. Create a `feature/*` or `fix/*` branch.
2. Commit changes there.
3. Merge the feature/fix branch into `develop`.
4. Run quality checks.
5. Merge `develop` into `main`.
6. Push and tag the release if appropriate.

## Changed files and staging

Use the changed-file list to inspect staged, unstaged, and untracked files. Git Glide GUI uses explicit status badges so staged and unstaged changes are easier to distinguish.

For clean tracked files that do not appear in **Changed Files**, use:

```text
Stage -> Browse tracked files
```

This is useful when a committed file is unchanged but should be removed from Git or replaced.

Available file-removal workflows:

- **Remove file**: runs `git rm -- <file>` and deletes the file from disk.
- **Stop tracking**: runs `git rm --cached -- <file>` and keeps the local file.

Both actions require confirmation.

## History, recovery, and conflict safety

Use **History / Graph** to inspect a read-only `git log --graph` view before merging, pulling, deleting tags, or undoing commits.

Recovery tools include merge/cherry-pick guidance, abort/continue previews, conflict file listing, and conflict marker verification. Before staging a resolved conflict file, Git Glide GUI scans for complete conflict marker blocks:

```text
<<<<<<<
=======
>>>>>>>
```

If markers remain, staging is blocked and the UI shows the marker lines that still need attention.

## GitHub workflows

Use:

```text
Setup -> GitHub publish...
```

to connect a local repository to GitHub. The workflow helps build the remote URL, reminds you not to initialize a GitHub repo with README or `.gitignore` when pushing an existing local repo, and includes privacy reminders for private repositories and GitHub Copilot AI/data-training settings.

Use:

```text
Setup -> GitHub diagnostics...
```

to inspect remotes, upstream tracking, repository access, and push-with-upstream behavior.

Useful supported commands include:

```bat
git remote -v
git branch --show-current
git push -u origin HEAD
git ls-remote --heads origin
```

If GitHub returns a pull-request URL after pushing a branch, Git Glide GUI can surface it for opening or copying.

## Merge and publish workflow

Use:

```text
Integrate -> Merge & Publish
```

to inspect branch tracking, push a new branch with upstream, sync `main -> develop`, merge a selected feature branch into `develop`, run quality checks, and promote `develop -> main`.

Typical flow:

```bat
git switch feature/my-work
git push -u origin HEAD

git switch develop
git merge --no-ff feature/my-work
git push

scripts\windows\run-quality-checks.bat

git switch main
git merge --no-ff develop
git push
```

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

## Recent release highlights

- **v3.6.3**: history/graph polish with ASCII-safe graph badges and branch/tag/remote indicators.
- **v3.6.4**: splitter shutdown stability and first-commit unstage fix using `git rm --cached`.
- **v3.6.5**: conflict marker verification before staging resolved files.
- **v3.6.6**: GitHub publish guidance and privacy reminders.
- **v3.6.7**: GitHub diagnostics, upstream guidance, safer remove/stop-tracking workflows, and clearer file status badges.
- **v3.6.7.1**: GitHub remote parser compatibility fix for Windows PowerShell 5.1 / Pester 3.
- **v3.6.8**: tracked-file browser for clean-file removal/replacement workflows.
- **v3.6.9**: Merge & Publish workflow restoration.
- **v3.6.10**: dirty-work branch switching now warns but allows the user to continue when Git itself allows it.
- **v3.6.10.1**: protected-branch workflow guard.
- **v3.6.11**: branch context banner and workflow guard reliability.
- **v3.6.12**: UI organization with Simple, Workflow, and Expert modes plus command palette entry point.

## More documentation

See:

```text
docs/REPOSITORY_WORKFLOW.md
docs/RELEASE_NOTES_v3_6_12.md
docs/ROADMAP_REVIEW_v3_6_12.md
docs/SWOT_AND_ROADMAP_v3_6_12.md
```
