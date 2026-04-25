# Git Glide GUI v3.6.4 - SWOT and Roadmap

## Strengths added in v3.6.4

- The package version is internally consistent again.
- History / Graph is easier to read because branch, remote, tag, and merge rows are separated into visible columns and ASCII badges.
- The selected visual row keeps the full commit hash internally, reducing ambiguity when preparing cherry-pick or show commands.
- ScriptAnalyzer is now a useful optional quality signal instead of a flood of style warnings.

## Remaining weaknesses

- The graph is still a model/table view, not a true drawn lane graph.
- Conflict resolution is still guided; it does not yet verify conflict markers inside files before staging.
- External merge tool profiles are still a single command string, not saved named profiles.
- Rebase is still mostly recovery-oriented rather than a guided workflow.

## Recommended v3.6.4

1. Add file-level conflict helper actions:
   - open selected conflicted file
   - open containing folder
   - verify whether conflict markers remain
   - stage only after marker check or explicit confirmation
2. Add resolved-file verification summary:
   - unresolved files
   - staged resolved candidates
   - files still containing `<<<<<<<`, `=======`, or `>>>>>>>`
3. Add tests for conflict-marker scanning and stage-resolved safety guidance.

## Later roadmap

- Configurable external merge/diff tool profiles.
- Interactive rebase helper.
- Reflog recovery browser.
- GitHub/GitLab pull request integration planning.
