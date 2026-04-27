#!/usr/bin/env python3
"""Collect Git Glide GUI product, quality, release, and technical-debt metrics."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import re
import subprocess
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
METRICS_DIR = ROOT / "metrics"
SNAPSHOT_DIR = METRICS_DIR / "snapshots"
MAX_GUI_SCRIPT_LINES = 4000


def run_git(args: list[str]) -> tuple[int, str, str]:
    try:
        p = subprocess.run(["git", *args], cwd=str(ROOT), text=True, capture_output=True, check=False)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except FileNotFoundError:
        return 127, "", "git not found"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(read_text(path))


def list_files() -> list[Path]:
    result: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith(".git/") or rel.startswith("metrics/snapshots/") or "__pycache__" in rel:
            continue
        result.append(path)
    return result


def classify_files(files: list[Path]) -> dict[str, list[str]]:
    groups = {"runtime_scripts": [], "modules": [], "tests": [], "docs": [], "metrics": [], "launchers": []}
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        name = path.name.lower()
        if rel.startswith("scripts/windows/") and name.endswith(".ps1"):
            groups["runtime_scripts"].append(rel)
        if rel.startswith("modules/") and name.endswith(".psm1"):
            groups["modules"].append(rel)
        if rel.startswith("tests/"):
            groups["tests"].append(rel)
        if rel.startswith("docs/") or name == "readme.md":
            groups["docs"].append(rel)
        if rel.startswith("metrics/") or rel.startswith("scripts/metrics/"):
            groups["metrics"].append(rel)
        if name.endswith(".bat"):
            groups["launchers"].append(rel)
    return {k: sorted(v) for k, v in groups.items()}


def count_todo_markers(files: list[Path]) -> int:
    pattern = re.compile(r"\b(TODO|FIXME|HACK)\b", re.IGNORECASE)
    count = 0
    for path in files:
        if path.suffix.lower() not in {".ps1", ".psm1", ".py", ".bat", ".md", ".json"}:
            continue
        try:
            count += sum(1 for line in read_text(path).splitlines() if pattern.search(line))
        except Exception:
            continue
    return count


def latest_tag() -> str:
    code, out, _ = run_git(["describe", "--tags", "--abbrev=0"])
    return out if code == 0 else ""


def current_branch() -> str:
    code, out, _ = run_git(["branch", "--show-current"])
    return out if code == 0 else ""


def is_release_churn_candidate(rel_path: str) -> bool:
    lower = rel_path.lower()
    if lower in {"version", "manifest.json", "readme.md", "docs/start_here.md"}:
        return True
    if lower.startswith(("docs/release_notes", "docs/files_changed", "docs/manifest", "docs/changelog", "docs/release_checklist")):
        return True
    if lower.endswith(".bat") and ("quality" in lower or "git-glide" in lower):
        return True
    if lower.startswith("scripts/windows/") and any(x in lower for x in ["package-release", "smoke-launch", "run-quality"]):
        return True
    return False


def blob_size_at_ref(ref: str, rel_path: str) -> int:
    code, out, _ = run_git(["cat-file", "-s", f"{ref}:{rel_path}"])
    return int(out) if code == 0 and out.isdigit() else 0


def git_release_window_metrics(base_ref: str) -> dict[str, Any]:
    if not base_ref:
        return {
            "baseline_ref": "",
            "commit_count_since_baseline": 0,
            "merge_commit_count_since_baseline": 0,
            "non_merge_commit_count_since_baseline": 0,
            "changed_file_count_since_baseline": 0,
            "added_lines_since_baseline": 0,
            "deleted_lines_since_baseline": 0,
            "changed_files_since_baseline": [],
            "release_churn_candidate_files": [],
            "release_churn_ratio": 0.0
        }

    rev = f"{base_ref}..HEAD"
    _, commit_count, _ = run_git(["rev-list", "--count", rev])
    _, merge_count, _ = run_git(["rev-list", "--count", "--merges", rev])
    _, changed_text, _ = run_git(["diff", "--name-only", rev])
    changed = [x.strip() for x in changed_text.splitlines() if x.strip()]

    _, numstat, _ = run_git(["diff", "--numstat", rev])
    added = 0
    deleted = 0
    for line in numstat.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            if parts[0].isdigit():
                added += int(parts[0])
            if parts[1].isdigit():
                deleted += int(parts[1])

    churn = [p for p in changed if is_release_churn_candidate(p)]
    commits = int(commit_count) if commit_count.isdigit() else 0
    merges = int(merge_count) if merge_count.isdigit() else 0
    return {
        "baseline_ref": base_ref,
        "commit_count_since_baseline": commits,
        "merge_commit_count_since_baseline": merges,
        "non_merge_commit_count_since_baseline": max(0, commits - merges),
        "changed_file_count_since_baseline": len(changed),
        "added_lines_since_baseline": added,
        "deleted_lines_since_baseline": deleted,
        "changed_files_since_baseline": changed,
        "release_churn_candidate_files": churn,
        "release_churn_ratio": round((len(churn) / len(changed)) if changed else 0.0, 4)
    }


def change_surface_metrics(base_ref: str) -> dict[str, Any]:
    if not base_ref:
        return {"added_kib": 0.0, "changed_kib": 0.0, "deleted_kib": 0.0, "package_change_surface_kib": 0.0, "net_package_growth_kib": 0.0}

    _, status_text, _ = run_git(["diff", "--name-status", "--find-renames", f"{base_ref}..HEAD"])
    added = changed = deleted = old_total = new_total = 0

    for line in status_text.splitlines():
        parts = line.split("\t")
        if not parts:
            continue
        status = parts[0]
        if status.startswith("R") and len(parts) >= 3:
            old_path, new_path = parts[1], parts[2]
            old_size = blob_size_at_ref(base_ref, old_path)
            new_file = ROOT / new_path
            new_size = new_file.stat().st_size if new_file.exists() else 0
            changed += max(old_size, new_size)
            old_total += old_size
            new_total += new_size
        elif status == "A" and len(parts) >= 2:
            size = (ROOT / parts[1]).stat().st_size if (ROOT / parts[1]).exists() else 0
            added += size
            new_total += size
        elif status == "D" and len(parts) >= 2:
            size = blob_size_at_ref(base_ref, parts[1])
            deleted += size
            old_total += size
        elif len(parts) >= 2:
            rel = parts[1]
            old_size = blob_size_at_ref(base_ref, rel)
            new_file = ROOT / rel
            new_size = new_file.stat().st_size if new_file.exists() else 0
            changed += max(old_size, new_size)
            old_total += old_size
            new_total += new_size

    surface = added + changed + deleted
    return {
        "added_kib": round(added / 1024.0, 2),
        "changed_kib": round(changed / 1024.0, 2),
        "deleted_kib": round(deleted / 1024.0, 2),
        "package_change_surface_kib": round(surface / 1024.0, 2),
        "net_package_growth_kib": round((new_total - old_total) / 1024.0, 2)
    }


def feature_metrics(feature_manifest: dict[str, Any]) -> dict[str, Any]:
    features = feature_manifest.get("features", [])
    problems = feature_manifest.get("problems", [])
    active = [f for f in features if f.get("status") == "active"]
    planned = [f for f in features if f.get("status") == "planned"]

    feature_points = sum(int(f.get("value_weight", 0)) for f in active)
    risk_points = sum(int(f.get("risk_reduction_weight", 0)) for f in active)
    problem_points = sum(
        sum(int(p.get(k, 0)) for k in ["frequency", "severity", "time_cost", "risk_cost", "strategic_fit"])
        for p in problems
    )

    by_problem = {p.get("id", ""): 0 for p in problems}
    for f in active:
        for pid in f.get("problem_ids", []):
            by_problem[pid] = by_problem.get(pid, 0) + 1

    return {
        "problem_count": len(problems),
        "active_feature_count": len(active),
        "planned_feature_count": len(planned),
        "feature_points_total": feature_points,
        "risk_reduction_points_total": risk_points,
        "problem_value_points_total": problem_points,
        "features_per_problem": by_problem
    }


def technical_debt_score(files: list[Path], todo_count: int, manifest: dict[str, Any]) -> dict[str, Any]:
    line_counts = {}
    oversized = []
    modularity_pressure = 0.0

    script_paths = [manifest.get("main_script", ""), *manifest.get("split_script_parts", [])]
    for rel in script_paths:
        if not rel:
            continue
        path = ROOT / rel
        if not path.exists():
            continue
        count = len(read_text(path).splitlines())
        line_counts[rel] = count
        if count > MAX_GUI_SCRIPT_LINES:
            oversized.append(rel)
        if count > 1500:
            modularity_pressure += round((count - 1500) / 250.0, 2)

    versioned_runtime_count = len(list((ROOT / "scripts/windows").glob("GitGlideGUI-v*.ps1")))

    readme = read_text(ROOT / "README.md") if (ROOT / "README.md").exists() else ""
    start_here = read_text(ROOT / "docs/START_HERE.md") if (ROOT / "docs/START_HERE.md").exists() else ""
    docs_missing = 0
    for marker in ["Why this exists", "What makes it different?", "Core Features", "Stable split-script layout"]:
        if marker not in readme:
            docs_missing += 1
    for marker in ["Requirements", "Validate the package", "If something looks wrong", "Stable split-script layout"]:
        if marker not in start_here:
            docs_missing += 1

    components = {
        "modularity_pressure": round(modularity_pressure, 2),
        "runtime_version_churn": float(versioned_runtime_count * 3),
        "docs_regression_risk": round(docs_missing * 1.5, 2),
        "todo_fixme_hack_debt": round(todo_count * 0.5, 2),
        "marker_test_brittleness": 3.0,
        "manual_release_process_debt": 3.5,
        "gui_behavioral_test_gap": 3.0
    }
    total = round(sum(components.values()), 2)
    return {
        "technical_debt_points_total": total,
        "components": components,
        "runtime_script_line_counts": line_counts,
        "oversized_script_files": oversized,
        "versioned_runtime_script_count": versioned_runtime_count,
        "todo_fixme_hack_count": todo_count
    }


def quality_score(debt: dict[str, Any], manifest: dict[str, Any]) -> int:
    score = 100
    if debt["oversized_script_files"]:
        score -= 15
    if debt["versioned_runtime_script_count"] > 0:
        score -= 15
    if debt["components"]["docs_regression_risk"] > 0:
        score -= min(15, int(debt["components"]["docs_regression_risk"] * 2))
    if not manifest.get("main_script") or not manifest.get("split_script_parts"):
        score -= 10
    if not (ROOT / "scripts/windows/GitGlideVersion.ps1").exists():
        score -= 10
    return max(0, min(100, score))


def main() -> int:
    version = read_text(ROOT / "VERSION").strip() if (ROOT / "VERSION").exists() else "0.0.0-dev"
    manifest = read_json(ROOT / "manifest.json", {})
    feature_manifest = read_json(ROOT / "metrics/feature_manifest.json", {"features": [], "problems": []})

    files = list_files()
    groups = classify_files(files)
    todos = count_todo_markers(files)
    tag = latest_tag()

    git = git_release_window_metrics(tag)
    surface = change_surface_metrics(tag)
    features = feature_metrics(feature_manifest)
    debt = technical_debt_score(files, todos, manifest)
    qscore = quality_score(debt, manifest)
    package_surface = max(surface["package_change_surface_kib"], 1.0)

    snapshot = {
        "schema_version": "1.0",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "repository_root": str(ROOT),
        "version": version,
        "current_branch": current_branch(),
        "latest_tag": tag,
        "manifest": {
            "version": manifest.get("version"),
            "main_script": manifest.get("main_script"),
            "split_script_parts": manifest.get("split_script_parts", [])
        },
        "file_inventory": {
            "total_files": len(files),
            "runtime_script_file_count": len(groups["runtime_scripts"]),
            "module_file_count": len(groups["modules"]),
            "test_file_count": len(groups["tests"]),
            "doc_file_count": len(groups["docs"]),
            "runtime_script_files": groups["runtime_scripts"],
            "module_files": groups["modules"],
            "test_files": groups["tests"],
            "doc_files": groups["docs"]
        },
        "git": git,
        "change_surface": surface,
        "feature_value": features,
        "technical_debt": debt,
        "scores": {
            "quality_score": qscore,
            "net_maturity_score": round(features["feature_points_total"] - debt["technical_debt_points_total"], 2),
            "feature_points_per_kib": round(features["feature_points_total"] / package_surface, 4),
            "debt_points_per_kib": round(debt["technical_debt_points_total"] / package_surface, 4)
        }
    }

    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    version_slug = version.replace(".", "_")
    version_path = SNAPSHOT_DIR / f"gitglide_metrics_v{version_slug}.json"
    latest_path = SNAPSHOT_DIR / "gitglide_metrics_latest.json"
    text = json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n"
    version_path.write_text(text, encoding="utf-8")
    latest_path.write_text(text, encoding="utf-8")

    print(f"Wrote metrics snapshot: {version_path.relative_to(ROOT).as_posix()}")
    print(f"Wrote latest snapshot:  {latest_path.relative_to(ROOT).as_posix()}")
    print(f"Net maturity score:    {snapshot['scores']['net_maturity_score']}")
    print(f"Technical debt points: {debt['technical_debt_points_total']}")
    print(f"Quality score:         {qscore}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
