#!/usr/bin/env python3
"""Generate a Markdown metrics report from the latest Git Glide metrics snapshot."""

from __future__ import annotations

from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "metrics/snapshots/gitglide_metrics_latest.json"
REPORT = ROOT / "metrics/METRICS_REPORT.md"


def pct(value: float) -> str:
    return f"{value * 100:.1f}%"


def main() -> int:
    if not SNAPSHOT.exists():
        raise FileNotFoundError("Metrics snapshot missing. Run scripts/windows/collect-metrics.bat first.")

    data = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    git = data.get("git", {})
    surface = data.get("change_surface", {})
    features = data.get("feature_value", {})
    debt = data.get("technical_debt", {})
    scores = data.get("scores", {})

    lines = [
        "# Git Glide GUI Metrics Report",
        "",
        f"Generated: `{data.get('generated_at_utc', '')}`",
        "",
        "## Summary",
        "",
        f"- Version: `{data.get('version', '')}`",
        f"- Branch: `{data.get('current_branch', '')}`",
        f"- Baseline tag: `{data.get('latest_tag', '')}`",
        f"- Quality score: **{scores.get('quality_score', 0)} / 100**",
        f"- Net maturity score: **{scores.get('net_maturity_score', 0)}**",
        f"- Technical debt points: **{debt.get('technical_debt_points_total', 0)}**",
        f"- Feature points total: **{features.get('feature_points_total', 0)}**",
        "",
        "## Release window",
        "",
        f"- Commits since baseline: {git.get('commit_count_since_baseline', 0)}",
        f"- Merge commits since baseline: {git.get('merge_commit_count_since_baseline', 0)}",
        f"- Non-merge commits since baseline: {git.get('non_merge_commit_count_since_baseline', 0)}",
        f"- Changed files since baseline: {git.get('changed_file_count_since_baseline', 0)}",
        f"- Added lines since baseline: {git.get('added_lines_since_baseline', 0)}",
        f"- Deleted lines since baseline: {git.get('deleted_lines_since_baseline', 0)}",
        f"- Release churn ratio: {pct(float(git.get('release_churn_ratio', 0.0)))}",
        "",
        "## Package change surface",
        "",
        f"- Added KiB: {surface.get('added_kib', 0)}",
        f"- Changed KiB: {surface.get('changed_kib', 0)}",
        f"- Deleted KiB: {surface.get('deleted_kib', 0)}",
        f"- Package change surface KiB: **{surface.get('package_change_surface_kib', 0)}**",
        f"- Net package growth KiB: **{surface.get('net_package_growth_kib', 0)}**",
        "",
        "## Feature and problem model",
        "",
        f"- Problem count: {features.get('problem_count', 0)}",
        f"- Active feature count: {features.get('active_feature_count', 0)}",
        f"- Planned feature count: {features.get('planned_feature_count', 0)}",
        f"- Feature points total: {features.get('feature_points_total', 0)}",
        f"- Risk-reduction points total: {features.get('risk_reduction_points_total', 0)}",
        f"- Problem value points total: {features.get('problem_value_points_total', 0)}",
        "",
        "## Technical debt",
        ""
    ]

    for name, value in debt.get("components", {}).items():
        lines.append(f"- {name}: {value}")

    lines.extend(["", "## Runtime script line counts", ""])
    for rel, count in debt.get("runtime_script_line_counts", {}).items():
        lines.append(f"- `{rel}`: {count}")

    lines.extend(["", "## Release churn candidate files", ""])
    candidates = git.get("release_churn_candidate_files", [])
    if candidates:
        for rel in candidates:
            lines.append(f"- `{rel}`")
    else:
        lines.append("- None detected.")

    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote metrics report: {REPORT.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
