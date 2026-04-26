# Git Glide GUI v3.7.0 — Branch Sync & Conflict Recovery UX

## Goal

v3.7.0 turns the recent detached-HEAD/diverged-branch/conflict-marker workflow into first-class GUI support.

## Added

- Repository State Doctor in the Recovery tab.
- Plain-English diagnosis for:
  - detached HEAD
  - branch ahead/behind/diverged from upstream
  - merge/rebase/cherry-pick in progress
  - unresolved conflict files
  - leftover conflict markers
  - suspicious untracked root item named `git`
- Conflict marker scanner for changed and unmerged files.
- GUI script parser validation button.
- Command previews for State Doctor, marker scan, and script validation.

## Improved

- Changed-files context banner now recalculates its height when the available width or text changes.
- The changed-files banner row is explicitly resized instead of relying on `AutoSize` behavior in a `TableLayoutPanel`.
- Recovery tab layout now separates:
  - recovery controls
  - Repository State Doctor
  - unresolved conflict files
  - detailed guidance output
  - summary/status labels

## Safety

- State Doctor does not perform destructive operations.
- Recovery buttons continue to rely on confirmation dialogs where abort/continue operations could change repository state.
- Marker scanning blocks premature staging through the existing resolved-file staging flow when conflict markers remain.

## Manual smoke checks

1. Start the GUI with `git-glide-gui.bat`.
2. Open the Recovery tab.
3. Click **State doctor** on:
   - clean branch
   - branch ahead of origin
   - branch behind origin
   - diverged branch
   - detached HEAD
   - merge conflict in progress
4. Click **Find markers** with and without conflict markers in changed files.
5. Click **Validate GUI script** and confirm `PowerShell parse OK`.
6. Resize the left work-area panel and confirm the branch context banner wraps and resizes vertically.

## Suggested commit

```bat
git add VERSION git-glide-gui.bat scripts/windows/GitGlideGUI-v3.7.0.ps1 docs/CHANGELOG_V3_7_0.md scripts/windows/run-git-glide-v3.7-quality-checks.ps1
git commit -m "feat: add v3.7 repository state doctor and conflict recovery UX"
git push
```
