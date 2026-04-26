# Git Glide GUI v3.6.11 - Branch context and workflow guard reliability

This release focuses on preventing workflow drift rather than adding more raw Git commands.

## Added

- Branch context banner directly above the Changed Files list.
- Branch-role detection for main, develop, feature/*, fix/*, hotfix/*, release/*, and custom branches.
- Protected-branch workflow guard for stage-all and commit operations.
- Create-branch-first path when the user is about to work directly on main or develop.
- Last-refresh hint when the working tree is clean.
- Package-release script restored to match static smoke expectations.

## Fixed

- Visible window title and audit version now match the package version.
- Fresh ZIP packages should contain the files expected by static smoke tests.
