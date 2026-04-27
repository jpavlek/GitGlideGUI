# Git Glide GUI v3.8.2 Patch Snippets

## tests/static_smoke_test.py

Add these required files:

```python
"metrics/metric_definitions.json",
"metrics/feature_manifest.json",
"metrics/snapshots/.gitkeep",
"scripts/metrics/collect_gitglide_metrics.py",
"scripts/metrics/generate_metrics_report.py",
"scripts/windows/collect-metrics.bat",
"docs/METRICS_AND_VALUE_MODEL.md",
f"docs/RELEASE_NOTES_v{version.replace('.', '_')}.md",
```

Add marker checks after `require_paths(required)`:

```python
require_markers(
    "metrics/metric_definitions.json",
    [
        "package_change_surface_kib",
        "technical_debt_points_total",
        "net_maturity_score",
        "release_churn_ratio",
    ],
    "metric definitions",
)

require_markers(
    "metrics/feature_manifest.json",
    [
        "git.decision_safety",
        "branch.merge_safety",
        "quality.observability",
        "quality.metrics_observability",
    ],
    "feature manifest",
)

require_markers(
    "scripts/metrics/collect_gitglide_metrics.py",
    [
        "technical_debt_score",
        "change_surface_metrics",
        "feature_metrics",
        "git_release_window_metrics",
    ],
    "metrics collector",
)

require_markers(
    "scripts/windows/collect-metrics.bat",
    [
        "collect_gitglide_metrics.py",
        "generate_metrics_report.py",
    ],
    "metrics launcher",
)

require_markers(
    "docs/METRICS_AND_VALUE_MODEL.md",
    [
        "Package Change Surface",
        "Feature points",
        "Technical debt points",
        "Net maturity",
    ],
    "metrics documentation",
)
```

## README.md

Add `docs/METRICS_AND_VALUE_MODEL.md` and `docs/RELEASE_NOTES_v3_8_2.md` to the Documentation section.

## docs/START_HERE.md

Add a small section after "Validate the package":

```markdown
## Collect metrics

To generate a local metrics snapshot and Markdown report, run:

```bat
scripts\windows\collect-metrics.bat
```

Outputs:

```text
metrics/snapshots/gitglide_metrics_latest.json
metrics/METRICS_REPORT.md
```
```

## scripts/windows/run-quality-checks.bat

Optional: add metrics collection as a fifth step after PSScriptAnalyzer.

```bat
echo.
echo [5/5] Metrics collection
call scripts\windows\collect-metrics.bat
if errorlevel 1 exit /b 1
```
