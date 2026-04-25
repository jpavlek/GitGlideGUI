# Contributing to Git Glide GUI

## Development rules

1. Run `run-quality-checks.bat` before packaging or tagging a release.
2. Keep UI changes small and preserve the working GUI path.
3. Prefer extracting testable command-planning logic into `modules/GitGlideGUI.Core/`.
4. Add or update Pester tests for every extracted module.
5. Add release notes and roadmap review for each version.

## Branch naming

```text
feature/v3-7-visual-graph-polish
fix/v3-6-1-parser-regression
docs/v3-6-repository-workflow
```

## Release checklist

```bat
run-quality-checks.bat
scripts\windows\package-release.bat
```
