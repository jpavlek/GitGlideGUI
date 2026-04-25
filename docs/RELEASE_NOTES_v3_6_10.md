# Git Glide GUI v3.6.10 - Branch switch dirty-work choice

v3.6.10 improves branch switching UX. Earlier versions warned when the working tree had changes and blocked switching completely. Git itself can often switch branches safely when dirty files do not overlap with the target branch, so Git Glide now warns but lets the user choose to attempt the switch anyway.

## Changed

- Branch switching still checks the working tree first.
- Dirty work now opens a warning with a **switch anyway** choice.
- If the user continues, Git runs the normal `git switch <branch>` command.
- Git remains the final safety gate and will stop if switching would overwrite local work.
- Pull, merge, and other higher-risk operations keep stricter clean-working-tree checks.

## Why

This keeps Git Glide safer than a silent switch while avoiding unnecessary friction for experienced users.
