# Git Glide GUI v2.4 — SWOT and Roadmap Update

## v2.4 priority result

The highest-priority user-facing bug was repository context confusion. The log showed Git commands running in the extracted tool directory rather than the intended repository. v2.4 fixes this through repository discovery, a repository picker, and no-repository guards.

## SWOT update

### Strengths
- Clearer product identity: Git Glide GUI.
- Better safety posture through audit logging, custom command checks, and destructive-command confirmations.
- New repository picker reduces startup confusion.
- Backward compatibility with the old launcher.
- Testable core modules for command safety and repository status.

### Weaknesses
- Still largely a monolithic WinForms script.
- Live GUI testing still depends on Windows.
- Repository picker is functional but not yet a full multi-repository workspace.
- No visual commit graph yet.

### Opportunities
- Convert repository selection into a recent-repositories/workspace panel.
- Make suggested next action clickable.
- Add Beginner/Advanced mode.
- Add branch/stash/tag integration tests against temporary repositories.
- Continue extracting Git services from the monolithic UI.

### Threats
- Mature Git GUI competitors already provide visual graph and conflict tools.
- Monolithic UI changes can regress behavior without stronger Windows CI.
- Users may still expect the tool to automatically know the intended repository when launched from arbitrary folders.

## Recommended v2.5 priority

1. Make **Suggested Next Action** clickable for safe actions.
2. Add **Beginner / Advanced mode**.
3. Add branch, stash, and tag temporary-repository integration tests.
4. Start extracting `GitActionService` for common command execution and command previews.
