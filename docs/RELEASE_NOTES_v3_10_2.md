# Git Glide GUI v3.10.2 Release Notes

## Theme

Release hygiene, quality-gate hardening, and layout-host consistency.

v3.10.2 is intentionally a stabilization release. It does not add another large visible workflow panel. It makes the v3.10.1 Collapsible Panel Host more trustworthy by cleaning release artifacts, making stale package state detectable, and aligning the GUI panel-host IDs with the core Layout State Model.

## Added

- Metrics collection now runs before the static smoke test in the full quality gate.
- Static smoke now checks release consistency across `VERSION`, `manifest.json`, `README.md`, `docs/START_HERE.md`, `metrics/METRICS_REPORT.md`, and the latest metrics snapshot.
- Static smoke now checks launcher/script references for stale versioned runtime scripts that are not included in the package.
- `GitLayoutState.psm1` now exposes a canonical panel registry through `Get-GglsCanonicalPanelRegistry`.
- `GitLayoutState.psm1` now exposes `Get-GglsCanonicalPanelId` and maps legacy `commandOutput` to `liveOutput`.
- `manual` is now the visible default save policy. Legacy `ask-on-exit` values are normalized to `manual`.

## Changed

- Updated package metadata, current documentation, metrics report, and latest metrics snapshot to v3.10.2.
- Updated `run-quality-checks.bat` to perform metrics refresh before strict release consistency checks.
- Updated Layout State tests to cover canonical layout-host panel IDs and legacy `commandOutput` aliasing.
- Updated user-facing save-policy wording to match actual non-modal shutdown behavior.

## Removed

- Removed stale v3.7 launcher artifacts from the release package. The supported entry points are now the stable `git-glide-gui.bat` launcher and the compatibility `git-flow-gui2.bat` launcher.

## Why this matters

A Git safety tool must model good release hygiene itself. Broken launchers, stale metrics reports, or unclear layout-state IDs reduce trust. v3.10.2 makes those defects harder to ship unnoticed.
