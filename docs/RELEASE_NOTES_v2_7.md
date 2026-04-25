# Git Glide GUI v2.8 Release Notes

## Focus

v2.8 improves onboarding clarity, visual polish, guided next actions, beginner/advanced workflow separation, and automated test coverage.

## User-facing changes

- Reworked the initial repository choice into three intention-based choices:
  - **Open existing repo**
  - **Init new repo**
  - **Continue without repo**
- Added richer explanatory text and hover tooltips to the startup choice cards.
- Added a clickable **Do it** button beside **Suggested next action** for safe cases.
- Added **Beginner / Advanced mode**:
  - Beginner mode keeps common tabs visible.
  - Advanced mode restores Integrate, Custom Git, Appearance, and Tags / Release tabs.
- Improved action-tab padding and tab layout for a less crowded first impression.

## Engineering changes

- Added `modules/GitGlideGUI.Core/GitRepositoryOnboarding.psm1`.
- Moved UI-free onboarding helpers into the new module:
  - `.gitignore` template names/content
  - remote-name validation
  - init command planning
  - first-commit command preview generation
- The main WinForms script still contains fallback logic so the GUI remains resilient if a module is missing.

## Test changes

Added Pester tests for:

- onboarding helper module
- temporary repository initialization
- `.gitignore` creation
- first commit workflow
- stash create/list/drop workflow
- annotated tag create/list/delete workflow

Static package smoke test was updated for v2.8.

## Compatibility

- Primary launcher: `git-glide-gui.bat`
- Compatibility launcher: `git-flow-gui2.bat`
- Main script: `scripts/windows/GitGlideGUI-v2.8.ps1`

## Known limitation

The package was statically validated in a Linux container. Live WinForms execution must be tested on Windows 10/11 with Git installed.
