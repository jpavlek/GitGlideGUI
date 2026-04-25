# Git Glide GUI v2.6 Release Notes

## Focus

v2.6 improves onboarding for new and existing repositories. It treats a folder without `.git` as a valid user intention instead of only an error condition.

## Added

- Intention-based startup dialog:
  - **Open existing repo**
  - **Init new repo**
  - **Continue without repo**
- New **Setup** action tab.
- **First commit...** wizard:
  - optional `.gitignore` creation/update
  - stage all files
  - create the initial commit
  - optional remote URL and push
- **Add .gitignore...** action with templates:
  - General / Windows
  - PowerShell
  - C++ / CMake
  - Unreal Engine
  - Python
  - Node / Web
  - Visual Studio
- **Add remote...** action:
  - add or update a remote
  - optional push with upstream tracking

## Improved

- Header buttons now use clearer intent-oriented labels:
  - **Open existing...**
  - **Init new...**
- Startup guidance no longer uses ambiguous Yes/No/Cancel labels for repository choice.
- Suggested next action text now better reflects repository onboarding states.

## Compatibility

- Primary launcher: `git-glide-gui.bat`
- Backward-compatible launcher: `git-flow-gui2.bat`
- Main script: `scripts/windows/GitGlideGUI-v2.6.ps1`

## Known limitation

This package was statically validated in a Linux container. The WinForms GUI should be live-tested on Windows 10/11 with Git installed.
