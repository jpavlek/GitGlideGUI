# Git Glide GUI v3.6.1 Release Notes

## Purpose

v3.6.1 is a stabilization and repository-tracking release.

## Fixed

- Fixed a PowerShell parser error in recovery text caused by `$kind:` interpolation. The script now uses `${kind}:`.
- Extended the static smoke test to catch this parser-regression pattern before packaging.

## Added

- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `VERSION`
- `.gitignore`
- `.gitattributes`
- `docs/REPOSITORY_WORKFLOW.md`
- `scripts/windows/init-gitglide-repo.ps1`

## Recommended local repository setup

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\init-gitglide-repo.ps1
```
