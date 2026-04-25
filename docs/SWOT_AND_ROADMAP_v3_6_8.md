# Git Glide GUI v3.6.8 SWOT and Roadmap Update

## Strength added

The Stage workflow now covers clean tracked files as well as changed files. This supports deliberate replacement, cleanup, and stop-tracking decisions.

## Weakness reduced

Previously, `git rm` and `git rm --cached` required a file to appear in Changed Files. Clean tracked files had no selection path.

## Risk

`git rm` is destructive, so the GUI keeps confirmation dialogs and clearly separates it from `git rm --cached`, which keeps local files.
