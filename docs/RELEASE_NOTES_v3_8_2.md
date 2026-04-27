# Git Glide GUI v3.8.2 Release Notes

## Theme

Metrics, value, technical-debt, and release-quality observability.

## Metrics added

- Local metrics collector for repository structure, Git release-window metrics, feature points, technical-debt points, package change surface, and quality score.
- Markdown metrics report generator.
- Feature/problem manifest that maps user problems to features and value weights.
- Metric definitions for release churn, package change surface, net maturity, feature density, and technical-debt scoring.

## Scripts added

- `scripts/windows/collect-metrics.bat`
- `scripts/metrics/collect_gitglide_metrics.py`
- `scripts/metrics/generate_metrics_report.py`

## Documentation added

- `docs/METRICS_AND_VALUE_MODEL.md`
- `metrics/metric_definitions.json`
- `metrics/feature_manifest.json`

## Risk managed

- Metrics scripts are dependency-free Python scripts.
- Metrics are local-only and do not transmit project information.
- Generated snapshots are written under `metrics/snapshots`.
- The model separates observable measurements from scored estimates.

## Technical-debt context

v3.8.1 reduced release churn by stabilizing runtime filenames. v3.8.2 makes that improvement measurable and prepares the project for future feature work with better visibility into value, debt, and release quality.
