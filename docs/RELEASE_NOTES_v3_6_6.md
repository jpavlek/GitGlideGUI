# Git Glide GUI v3.6.6 - GitHub Publish Guidance

## Focus

v3.6.6 adds a guided GitHub publish workflow for local repositories that already have commits.

## Added

- **GitHub publish** action in Setup.
- GitHub owner/repository validation and HTTPS/SSH remote URL generation.
- Default repository description text suitable for GitHub.
- Buttons to open GitHub new-repository page, open Copilot settings, copy the description, and show a privacy checklist.
- Private-repository guidance for client, commercial, security-sensitive, or unfinished code.
- Reminder that Git Glide GUI configures local Git remotes only; GitHub visibility and AI/data-training policies stay under GitHub account/repository settings.
- UI-free tests for GitHub URL and privacy guidance helpers.

## Recommended validation

```bat
cd /d scripts\windows
run-quality-checks.bat
```
