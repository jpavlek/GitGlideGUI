# Git Glide GUI v2.5 SWOT and Roadmap Update

## v2.5 focus

The previous v2.4 fix assumed that a non-repository folder was usually a mistake. That was incomplete: a user may intentionally open a normal project folder because they want to create a new Git repository.

v2.5 turns this from an error path into a guided onboarding path.

## Strength improved

- Better beginner experience.
- Clearer product behavior for new projects.
- Less confusing than raw `fatal: not a git repository` output.
- More aligned with the product name: Git Glide GUI should help users glide into Git, not only manage existing repositories.

## Remaining weaknesses

- The app is still monolithic at the UI level.
- Live GUI tests still require Windows.
- The first-commit/onboarding flow is not yet fully guided.
- No remote setup wizard yet.

## Recommended v2.6 priorities

1. Add a **First Commit Wizard** for newly initialized repositories.
2. Add optional `.gitignore` template selection.
3. Add optional remote setup: `git remote add origin <url>`.
4. Make **Suggested Next Action** clickable for safe actions.
5. Continue extracting services from the monolithic GUI.

