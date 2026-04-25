# Git Glide GUI v3.6.4 - SWOT and Roadmap

## Strengths added in v3.6.4

- Better behavior during resize/shutdown by avoiding a fragile high-frequency PowerShell WinForms event handler.
- Better beginner workflow support before the first commit.
- More accurate Git command selection based on repository state.

## Remaining weaknesses

- The main WinForms script is still large and should continue moving logic into testable modules.
- ScriptAnalyzer warnings remain non-blocking cleanup work.
- Conflict resolution can still be improved with marker verification before continuing operations.

## Next roadmap slice

Implement conflict-marker verification and safer "stage as resolved" behavior.
