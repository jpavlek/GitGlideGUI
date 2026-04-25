# Roadmap Review after Git Glide GUI v3.0

## Implemented from the roadmap

- Security hardening and safer custom-command parsing.
- Audit logging.
- Soft undo for last commit.
- Tag/release tab.
- Repository detection and repository picker.
- Init-new-repository flow.
- First commit wizard.
- `.gitignore` templates.
- Remote setup workflow.
- Suggested Next Action panel.
- Clickable safe suggested actions.
- Beginner / Advanced mode.
- Static smoke tests.
- Temporary Git repository tests.
- Branch-operation extraction.
- Staging/changed-file extraction.
- Stash-operation extraction.
- Dirty-working-tree guidance before switch, pull, merge, and now stash workflows.
- Minimal Windows smoke-launch script.

## Implemented outside the original roadmap

These were not initially prominent enough in the roadmap but proved important through real feedback:

- Rename from Git Flow GUI to Git Glide GUI.
- Backward-compatible launcher transition.
- Startup intent choices.
- Handling the extracted-tool-folder launch case.
- Treating non-repo folders as valid init-new-repo intent.
- First commit onboarding.
- Recovery guidance after stash apply/pop failures.
- Windows smoke-launch mode to catch parser regressions.

## Still to do

Important remaining items:

- Extract tag/release operations.
- Extract commit operations.
- Extract custom-command persistence and UI command registry.
- Add visual commit/branch graph.
- Add merge conflict UI.
- Add cherry-pick workflow.
- Add reflog-based recovery UI.
- Add file history / blame view.
- Add Git worktree support.
- Add GitHub/GitLab PR integration.
- Add CI pipeline for Windows parser/smoke checks.

## Roadmap revision

The roadmap should be revised slightly. Earlier roadmap items emphasized large visible features such as graph and merge UI. User feedback showed that startup correctness, parser regression detection, onboarding, and safe command planning are prerequisites for trust.

Revised near-term order:

1. Keep extracting risky Git workflows into tested modules.
2. Add Windows parser/smoke checks to every release.
3. Improve Beginner-mode guidance and Suggested Next Action coverage.
4. Then add larger visual features such as graph and conflict UI.
