# Git Glide GUI

Git Glide GUI is a lightweight, privacy-first Windows Git interface for safer human and AI-assisted software development. It turns fast coding changes into clear versioning choices, helping developers stay in control and use their judgment with command previews, visual staging, recovery guidance, custom actions, and quality checks.

## Quick start

```bat
git-glide-gui.bat
```

Or start with a repository path:

```bat
git-glide-gui.bat -RepositoryPath "D:\Projects\PersonalCloud\PersonalCloud_v33_3_9"
```

## Quality checks

```bat
run-quality-checks.bat
```

## Current focus: v3.6.13 workflow checklist and release consistency

v3.6.13 adds a Merge & Publish checklist so the feature -> develop -> quality checks -> main path is easier to follow without skipping steps. It also adds merged-branch cleanup guidance and stronger static smoke checks for version/package consistency.

## v3.6.12 UI organization and progressive disclosure

- Adds Simple, Workflow, and Expert UI modes to reduce visual overload without removing functionality.
- Keeps everyday actions visible while moving advanced workflows behind mode-aware tabs and searchable commands.
- Adds a command palette entry point so less common actions remain discoverable.
- Improves the Changed Files context banner with mode, branch, branch role, upstream, state, changed count, and recommended next action.

## v3.6.11 Branch context and workflow guard

- Shows branch role and recommended next step above Changed Files.
- Warns before staging or committing directly on protected branches.
- Offers a create-branch-first path so current changes can move to a feature/fix branch before commit.

## Repository tracking

This package is ready to be tracked as a dedicated Git repository. See `docs/REPOSITORY_WORKFLOW.md`.

## More documentation

Start with:

```text
docs/START_HERE.md
docs/REPOSITORY_WORKFLOW.md
docs/RELEASE_NOTES_v3_6_13.md
docs/ROADMAP_REVIEW_v3_6_13.md
docs/SWOT_AND_ROADMAP_v3_6_13.md
```
