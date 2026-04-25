# Git Glide GUI v3.6.9 - Git Flow merge/publish workflow restoration

## Focus

v3.6.9 restores and clarifies merge support that existed earlier but became too hidden or current-branch dependent. It adds a guided Merge & Publish path:

```text
feature branch -> develop -> quality checks -> main
```

## Added

- Branch tracking overview using `git branch -vv`.
- Push current branch with upstream using `git push -u origin HEAD`.
- Sync `main -> develop` workflow.
- Merge selected feature branch into `develop`, even while currently on `develop`.
- Quality-check gate button before merging `develop -> main`.
- Pull-request URL detection from GitHub push output.
