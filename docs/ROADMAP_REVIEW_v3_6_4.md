# Git Glide GUI v3.6.4 Roadmap Review

v3.6.4 advances the stability and beginner/onboarding parts of the roadmap. The most important improvement is handling repositories before their first commit, which is a common beginner path when creating `.gitignore`, staging files, and making the initial commit.

## Completed in this iteration

- Safer WinForms splitter behavior.
- Correct unstaging behavior in repositories without `HEAD`.
- Regression coverage for initial-repository staging workflows.

## Recommended next step

Continue with conflict verification: detect unresolved conflict markers before staging a file as resolved.
