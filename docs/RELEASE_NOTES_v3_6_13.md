# Git Glide GUI v3.6.13 Release Notes

## Focus

v3.6.13 improves workflow continuity and release trust. It adds a Merge & Publish checklist so the intended feature/fix -> develop -> quality checks -> main path is visible as a sequence, not just as separate buttons.

## Added

- Merge & Publish workflow checklist preview.
- Merged feature/fix branch cleanup command plans.
- UI action for cleaning up a selected merged branch after confirmation.
- Command palette entries for workflow checklist and merged-branch cleanup.
- Static smoke version/package consistency checks.

## Improved

- README now describes the current release instead of older merge workflow text.
- Repository workflow documentation now recommends one stable development folder and versioned release ZIPs.
- Static smoke now checks that VERSION, manifest, launcher, smoke launch, quality-check title, README, START_HERE, and versioned main script agree.

## Safety

The branch cleanup workflow uses `git branch -d`, not `git branch -D`, so Git itself refuses to delete a local branch it does not consider merged. Remote cleanup remains explicit and confirmed.

## Validation

Static smoke test and package integrity checks were run in the packaging environment. Windows validation should run:

```bat
scripts\windows\run-quality-checks.bat
```
