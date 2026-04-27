# Git Glide GUI Metrics and Value Model

## Purpose

Git Glide GUI is evolving quickly, so the project needs more than subjective release notes. The v3.8.2 metrics layer measures:

- iteration speed
- feature value
- problem coverage
- technical debt
- release churn
- package change surface
- quality and maturity

The goal is to answer whether a release made the software more valuable, more maintainable, and safer to use, or merely larger and noisier.

## Core principle

A feature has value because it solves or reduces a user problem.

Code has value because it supports features that solve problems.

## Package Change Surface

```text
Package Change Surface KiB =
  Added KiB
+ Changed KiB
+ Deleted KiB
```

Changed files use the larger of the old and new file size because a small byte delta can still require reviewing a large file.

## Feature points

Feature value uses a simple 1..5 scale:

```text
1 = small polish or compatibility fix
2 = useful improvement
3 = meaningful workflow feature
4 = high-value safety/productivity feature
5 = major product capability
```

The source of truth is:

```text
metrics/feature_manifest.json
```

## Technical debt points

Current technical debt is estimated from observable local signals:

```text
technical_debt_points =
  modularity_pressure
+ runtime_version_churn
+ docs_regression_risk
+ todo_fixme_hack_debt
+ marker_test_brittleness
+ manual_release_process_debt
+ gui_behavioral_test_gap
```

Lower is better.

## Net maturity

```text
Net Maturity Score =
  feature_points_total - technical_debt_points_total
```

A healthy release should increase net maturity.

## Release churn ratio

```text
Release Churn Ratio =
  release_churn_candidate_files / changed_files_since_baseline
```

## How to run

From the repository root:

```bat
scripts\windows\collect-metrics.bat
```

Outputs:

```text
metrics/snapshots/gitglide_metrics_latest.json
metrics/snapshots/gitglide_metrics_v<version>.json
metrics/METRICS_REPORT.md
```

## Current limitation

v3.8.2 introduces local measurable baselines. It does not yet measure real user telemetry, real time saved, or real avoided incidents.
