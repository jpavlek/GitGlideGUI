# Git Glide GUI v3.5 SWOT / Roadmap Update

## Hotfix assessment

v3.5 is a stabilization hotfix, not a feature release.

## Strength improved

- Better shutdown reliability.
- Lower risk of user-facing .NET/JIT error dialogs.
- More robust close-time cleanup.

## Weakness addressed

The app still has a large WinForms/PowerShell surface area, and event-handler exceptions can escape if not locally guarded. v3.5 fixes the observed FormClosing path and establishes the rule that shutdown handlers must never throw.

## Roadmap impact

The roadmap does not need a strategic rewrite, but one release-engineering rule should be added:

> All WinForms event handlers that run during startup, shutdown, or repository switching must be locally guarded and must not let PowerShell pipeline exceptions escape into WinForms.

## Next recommended version

v3.5 should continue with:

1. First read-only History / Graph tab.
2. History/graph service extraction.
3. Tests for history parsing with merge commits.
4. Conflict-resolution and cherry-pick workflow preparation.
