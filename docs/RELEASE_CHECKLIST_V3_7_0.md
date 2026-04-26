# Release Checklist — Git Glide GUI v3.7.0

## Before commit

```bat
git status -sb
run-quality-checks.bat
git-glide-gui.bat
```

Manual checks:

- GUI starts without parser errors.
- Recovery tab opens.
- State Doctor displays current branch state.
- Find markers reports no unresolved Git conflict markers in normal state.
- Validate GUI script reports `PowerShell parse OK`.
- Changed-files context banner wraps and resizes when the left panel is narrowed.

## Commit

```bat
git add VERSION README.md git-glide-gui.bat git-glide-gui-v3.7.0.bat run-quality-checks.bat scripts/windows/GitGlideGUI-v3.7.0.ps1 scripts/windows/run-git-glide-v3.7-quality-checks.ps1 scripts/windows/run-quality-checks.bat docs/CHANGELOG_V3_7_0.md docs/INSTALL_AND_RUN_V3_7_0.md docs/FILES_CHANGED_V3_7_0.md docs/MANIFEST_V3_7_0.txt docs/RELEASE_CHECKLIST_V3_7_0.md docs/ROADMAP_AFTER_V3_7.md

git commit -m "feat: add v3.7 repository state doctor and conflict recovery UX"
```

## Push

```bat
git push -u origin feature/v3-7-branch-sync-conflict-recovery
```

## Merge suggestion

After review and smoke test:

```bat
git switch develop
git pull
git merge --no-ff feature/v3-7-branch-sync-conflict-recovery -m "Merge v3.7 branch sync and conflict recovery UX"
git push origin develop
```
