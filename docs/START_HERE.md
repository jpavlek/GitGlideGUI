# Git Glide GUI v3.10.0 - Start Here

This guide helps you launch Git Glide GUI, choose the right first action, validate the package, and find the main workflows.

For the product overview, positioning, and v3.10.0 release focus, see `README.md`.

v3.10.0 adds the modular Layout State Model used to save splitter/window layout as structured data and prepare future collapsible, stackable, and dockable panels.

## Requirements

- Windows 10 or 11.
- Git installed and available from the command line.
- Windows PowerShell.

## Shortest path

From the package root:

```bat
run-quality-checks.bat
git-glide-gui.bat
```

Then either open an existing repository, initialize a new one, or continue without selecting a repository.

## Start the app

Preferred launcher:

```bat
git-glide-gui.bat
```

To open a specific repository:

```bat
git-glide-gui.bat -RepositoryPath "D:\Projects\YourRepo"
```

Compatibility launcher:

```bat
git-flow-gui2.bat
```

Use `git-flow-gui2.bat` only when you need the older compatibility entry point.

## First startup choices

- **Open existing repo**: choose a folder that already has `.git`.
- **Init new repo**: choose a normal folder and create a new Git repository there.
- **Continue without repo**: open the app without selecting a repository yet.

## Validate the package

Before using a new package or after integrating changes, run:

```bat
run-quality-checks.bat
```

The quality gate runs:

1. Static package/version/line-count smoke test.
2. Windows smoke launch with `-SmokeTest`.
3. Pester tests when Pester is installed.
4. PSScriptAnalyzer checks when PSScriptAnalyzer is installed.

For Pester-only test runs, use:

```bat
run-pester-tests.bat
```

This is useful when you want to rerun only the PowerShell module and workflow tests without repeating the full static smoke, launch, and analyzer checks.

## If something looks wrong

Start with:

```bat
git status
run-quality-checks.bat
```

Use the **Recovery** area when Git Glide GUI reports a risky repository state, such as a merge in progress, unresolved files, detached HEAD, or a branch that is ahead/behind its upstream.

If the GUI script itself fails to start, run:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
```

If a conflict was resolved manually, use the conflict marker scanner before staging resolved files.

## Collect metrics

To generate a local metrics snapshot and Markdown report, run:

```bat
scripts\windows\collect-metrics.bat
```

Outputs:

```text
metrics/snapshots/gitglide_metrics_latest.json
metrics/METRICS_REPORT.md
```

## Layout state and save policy

Open **Appearance** to inspect the v3.10.0 Layout State Model.

Available controls:

- **Save layout now** stores the current splitter/window state immediately.
- **Show layout state** displays the active layout profile and panel model.
- **Discard session layout** restores the saved layout without keeping temporary resizing.
- **Reset layout** returns layout state to the built-in defaults.
- **Save policy** controls whether layout is saved on exit: `ask-on-exit`, `always`, or `never`.

This is the foundation for v3.10.1+ collapsible, stackable, and dockable workspace panels.

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

## Recovery and Repository State Doctor

Use Recovery when the repository is in a risky or confusing state, such as:

- detached HEAD
- branch ahead/behind origin
- merge in progress
- cherry-pick in progress
- unresolved files
- conflict markers still present
- local changes that would be overwritten
- untracked files that would be overwritten

The Recovery area explains what happened, why it matters, and which next actions are safer.

## Conflict marker scanner

Before staging a resolved conflict file, Git Glide GUI can scan for complete conflict marker blocks:

```text
<<<<<<<
=======
>>>>>>>
```

If markers remain, staging is blocked and the UI shows the marker lines that still need attention.

## History, graph inspection, and branch relationships

Use **History / Graph** to inspect a read-only `git log --graph` view before merging, pulling, deleting tags, or undoing commits.

History inspection is useful before decisions such as:

- merging a feature branch
- syncing `develop` and `main`
- deleting a merged branch
- cherry-picking a commit
- undoing a local commit
- publishing a release branch

v3.8 introduced **Branch relationships** to make branch state easier to understand before risky actions.

Use **Branch relationships** to compare:

- current branch vs upstream
- current branch vs `develop`
- `develop` vs `main`

The relationship summary helps answer:

- Is this branch ahead?
- Is it behind?
- Has it diverged?
- Is it already merged?
- What is the merge base?
- Which commits are unique to each side?
- Should I pull, push, merge, or stop and inspect more carefully?

The relationship summary uses read-only Git commands:

```bat
git rev-list --left-right --count <left>...<right>
git merge-base --short <left> <right>
git log --oneline --left-right --cherry-pick -n12 <left>...<right>
```

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

run-quality-checks.bat

git switch main
git merge --no-ff develop
git push
```

## Stable split-script layout

v3.8.1 keeps the split-script layout introduced in v3.7.0 and stabilizes the runtime filenames.

The launcher calls:

```text
scripts/windows/GitGlideGUI.ps1
```

That entrypoint dot-sources:

```text
scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1
scripts/windows/GitGlideGUI.part02-state-selection.ps1
scripts/windows/GitGlideGUI.part03-previews-basic-ops.ps1
scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1
scripts/windows/GitGlideGUI.part05-ui.ps1
scripts/windows/GitGlideGUI.part06-run.ps1
```

The product version is read from `VERSION` and `manifest.json`. Runtime script filenames no longer need to change for every release.

## Development workflow for this package

For continued development, use a feature branch and run checks before committing:

```bat
git switch develop
git pull
git switch -c fix/v3-8-1-version-source-of-truth
run-quality-checks.bat
git-glide-gui.bat
```

Commit only after local quality checks pass.

## Recent release highlights

- **v3.6.13**: workflow checklist, merged-branch cleanup guidance, and release consistency smoke checks.
- **v3.7.0**: repository state clarity, conflict recovery UX, split-script layout, dynamic context banner sizing, color-coded diff rendering, and technical-debt reduction.
- **v3.8.0**: visual history and branch relationship understanding for safer merge, pull, push, cleanup, and release decisions.
- **v3.8.1**: version source-of-truth and release-churn reduction with stable runtime script filenames.

## More documentation

Start with:

```text
README.md
docs/RELEASE_NOTES_v3_8_1.md
docs/RELEASE_NOTES_v3_8.md
docs/ARCHITECTURE_v3_8.md
docs/REPOSITORY_WORKFLOW.md
docs/ROADMAP_REVIEW_v3_8.md
docs/SWOT_AND_ROADMAP_v3_8.md
docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_8.md
```


## Collapsible Panel Host

v3.10.1 adds Appearance-tab controls for collapsing and restoring selected workspace panels. Use this when the screen feels crowded, then click Save layout now to persist the current panel state.
