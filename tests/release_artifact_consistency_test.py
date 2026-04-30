#!/usr/bin/env python3
"""Git Glide GUI release artifact consistency checks.

This script is intentionally separate from static_smoke_test.py.

static_smoke_test.py checks the package/source shape before any generated
artifacts are refreshed. This script runs after collect-metrics.bat and verifies
that generated release artifacts agree with VERSION and manifest.json.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"Release artifact consistency failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.exists():
        fail(f"Missing required file: {relative_path}")
    return path.read_text(encoding="utf-8", errors="replace")


def read_json(relative_path: str) -> dict[str, Any]:
    text = read_text(relative_path)
    try:
        loaded = json.loads(text)
    except json.JSONDecodeError as exc:
        fail(f"Invalid JSON in {relative_path}: {exc}")
    if not isinstance(loaded, dict):
        fail(f"Expected JSON object in {relative_path}")
    return loaded


def require_contains(relative_path: str, markers: list[str], context: str) -> None:
    text = read_text(relative_path)
    missing = [marker for marker in markers if marker not in text]
    if missing:
        fail(f"{context} missing marker(s) in {relative_path}: {missing}")


def require_paths(relative_paths: list[str]) -> None:
    missing = [path for path in relative_paths if not (ROOT / path).exists()]
    if missing:
        fail(f"Missing required release artifact(s): {missing}")


def load_version() -> str:
    version = read_text("VERSION").strip()
    if not version:
        fail("VERSION is empty")
    return version


def assert_manifest_consistency(version: str) -> None:
    manifest = read_json("manifest.json")
    manifest_version = manifest.get("version")
    if manifest_version != version:
        fail(f"manifest.json version mismatch: VERSION={version!r}, manifest={manifest_version!r}")

    focus = str(manifest.get("iteration_focus", ""))
    if version not in focus:
        fail(f"manifest.json iteration_focus does not mention current version {version!r}")


def assert_docs_consistency(version: str) -> None:
    version_string = version.replace(".", "_")

    require_contains(
        "README.md",
        [
            f"# Git Glide GUI v{version}",
            f"Current focus: v{version}",
            f"docs/RELEASE_NOTES_v{version_string}.md",
        ],
        "README release consistency",
    )

    require_contains(
        "docs/START_HERE.md",
        [
            f"# Git Glide GUI v{version}",
            f"v{version}",
        ],
        "START_HERE release consistency",
    )

    require_paths(
        [
            f"docs/RELEASE_NOTES_v{version_string}.md",
            f"docs/LAYOUT_STATE_MODEL_v{version_string}.md",
            f"docs/ARCHITECTURE_v{version_string}.md",
            f"docs/TECHNICAL_DEBT_REDUCTION_PLAN_v{version_string}.md",
            f"docs/SWOT_AND_ROADMAP_v{version_string}.md",
            f"docs/ROADMAP_REVIEW_v{version_string}.md",
        ]
    )


def assert_metrics_consistency(version: str) -> None:
    version_string = version.replace(".", "_")

    require_paths(
        [
            "metrics/METRICS_REPORT.md",
            "metrics/snapshots/gitglide_metrics_latest.json",
            f"metrics/snapshots/gitglide_metrics_v{version_string}.json",
        ]
    )

    report = read_text("metrics/METRICS_REPORT.md")
    accepted_report_markers = [
        f"- Version: `{version}`",
        f"Version: `{version}`",
        f"version: {version}",
        f"version\": \"{version}\"",
    ]
    if not any(marker in report for marker in accepted_report_markers):
        fail(f"metrics/METRICS_REPORT.md is stale or does not report VERSION={version!r}")

    latest = read_json("metrics/snapshots/gitglide_metrics_latest.json")
    if latest.get("version") != version:
        fail(f"latest metrics snapshot version mismatch: VERSION={version!r}, latest={latest.get('version')!r}")
    latest_manifest_version = latest.get("manifest", {}).get("version")
    if latest_manifest_version != version:
        fail(
            "latest metrics snapshot manifest version mismatch: "
            f"VERSION={version!r}, latest manifest={latest_manifest_version!r}"
        )

    versioned_snapshot_path = f"metrics/snapshots/gitglide_metrics_v{version_string}.json"
    versioned = read_json(versioned_snapshot_path)
    if versioned.get("version") != version:
        fail(
            f"versioned metrics snapshot mismatch in {versioned_snapshot_path}: "
            f"VERSION={version!r}, snapshot={versioned.get('version')!r}"
        )
    versioned_manifest_version = versioned.get("manifest", {}).get("version")
    if versioned_manifest_version != version:
        fail(
            f"versioned metrics snapshot manifest mismatch in {versioned_snapshot_path}: "
            f"VERSION={version!r}, snapshot manifest={versioned_manifest_version!r}"
        )


def main() -> int:
    version = load_version()
    assert_manifest_consistency(version)
    assert_docs_consistency(version)
    assert_metrics_consistency(version)
    print("Release artifact consistency check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
