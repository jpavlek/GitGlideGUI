#!/usr/bin/env python3
"""Static smoke tests for the Git Glide GUI package.

This test intentionally checks explicit known paths and release consistency.
It avoids recursive os.walk, which prevents symlink/network-share traversal
problems, while still guarding against incomplete packages, stale launchers,
unresolved merge markers, stale versioned runtime scripts, and oversized GUI
implementation files.
"""

from pathlib import Path
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
MAX_GUI_SCRIPT_LINES = 4000
MAIN_SCRIPT = "scripts/windows/GitGlideGUI.ps1"
PARTS = [
    "scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1",
    "scripts/windows/GitGlideGUI.part02-state-selection.ps1",
    "scripts/windows/GitGlideGUI.part03-previews-basic-ops.ps1",
    "scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1",
    "scripts/windows/GitGlideGUI.part05-ui.ps1",
    "scripts/windows/GitGlideGUI.part06-run.ps1",
]


def fail(message):
    print(message)
    sys.exit(1)


def read_text(rel_path):
    return (ROOT / rel_path).read_text(encoding="utf-8", errors="replace")


def require_paths(paths):
    missing = [p for p in paths if not (ROOT / p).exists()]
    if missing:
        print("Missing required files:")
        for p in missing:
            print(" -", p)
        sys.exit(1)


def require_markers(rel_path, markers, label=None):
    text = read_text(rel_path)
    for marker in markers:
        if marker not in text:
            fail(f"Missing {label or rel_path} marker in {rel_path}: {marker}")


def reject_markers(rel_path, markers, label=None):
    text = read_text(rel_path)
    for marker in markers:
        if marker in text:
            fail(f"Forbidden {label or rel_path} marker found in {rel_path}: {marker}")


def assert_no_conflict_markers(rel_paths):
    for rel_path in rel_paths:
        for line_no, line in enumerate(read_text(rel_path).splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("<<<<<<<") or stripped.startswith(">>>>>>>") or stripped == "=======":
                fail(f"Unresolved conflict marker found: {rel_path}:{line_no}: {stripped}")


def assert_line_count_guard(rel_paths, max_lines):
    for rel_path in rel_paths:
        line_count = len(read_text(rel_path).splitlines())
        if line_count > max_lines:
            fail(f"Script file exceeds {max_lines}-line guard: {rel_path} has {line_count} lines")


version = read_text("VERSION").strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    fail(f"VERSION is not a semantic version like 3.8.1: {version!r}")

manifest = json.loads(read_text("manifest.json"))
if manifest.get("version") != version:
    fail(f"manifest.json version mismatch: VERSION={version!r}, manifest={manifest.get('version')!r}")

if manifest.get("main_script") != MAIN_SCRIPT:
    fail(f"manifest main_script mismatch: expected {MAIN_SCRIPT}, got {manifest.get('main_script')!r}")

expected_parts = PARTS
if manifest.get("split_script_parts") != expected_parts:
    fail("manifest split_script_parts does not match stable split script layout.")

version_string = version.replace('.', '_')
required = [
    "README.md",
    "VERSION",
    "manifest.json",
    "git-glide-gui.bat",
    "git-flow-gui2.bat",
    "run-quality-checks.bat",
    "run-pester-tests.bat",
    "PSScriptAnalyzerSettings.psd1",
    MAIN_SCRIPT,
    *PARTS,
    "metrics/feature_manifest.json",
    "metrics/metric_definitions.json",
    "metrics/snapshots/.gitkeep",
    "scripts/metrics/collect_gitglide_metrics.py",
    "scripts/metrics/generate_metrics_report.py",
    "scripts/windows/smoke-launch.ps1",
    "scripts/windows/run-quality-checks.bat",
    "scripts/windows/run-pester-tests.ps1",
    "scripts/windows/run-scriptanalyzer.ps1",
    "scripts/windows/init-gitglide-repo.ps1",
    "scripts/windows/package-release.ps1",
    "scripts/windows/GitGlideVersion.ps1",
    "scripts/windows/collect-metrics.bat",
    "modules/GitGlideGUI.Core/GitBranchOperations.psm1",
    "modules/GitGlideGUI.Core/GitCherryPickOperations.psm1",
    "modules/GitGlideGUI.Core/GitCommandSafety.psm1",
    "modules/GitGlideGUI.Core/GitCommitOperations.psm1",
    "modules/GitGlideGUI.Core/GitConflictRecovery.psm1",
    "modules/GitGlideGUI.Core/GitHistoryOperations.psm1",
    "modules/GitGlideGUI.Core/GitHubOperations.psm1",
    "modules/GitGlideGUI.Core/GitLearningGuidance.psm1",
    "modules/GitGlideGUI.Core/GitRepositoryOnboarding.psm1",
    "modules/GitGlideGUI.Core/GitRepositoryStatus.psm1",
    "modules/GitGlideGUI.Core/GitStagingOperations.psm1",
    "modules/GitGlideGUI.Core/GitStashOperations.psm1",
    "modules/GitGlideGUI.Core/GitTagOperations.psm1",
    "modules/GitGlideGUI.Core/GitConflictAssistant.psm1",
    "modules/GitGlideGUI.Core/GitBranchCleanup.psm1",
    "tests/GitBranchOperations.Tests.ps1",
    "tests/GitBranchCleanup.Tests.ps1",
    "tests/GitCherryPickOperations.Tests.ps1",
    "tests/GitCommandSafety.Tests.ps1",
    "tests/GitCommitOperations.Tests.ps1",
    "tests/GitConflictRecovery.Tests.ps1",
    "tests/GitHistoryOperations.Tests.ps1",
    "tests/GitHubOperations.Tests.ps1",
    "tests/GitLearningGuidance.Tests.ps1",
    "tests/GitRepositoryInitialization.Tests.ps1",
    "tests/GitRepositoryOnboarding.Tests.ps1",
    "tests/GitRepositoryStatus.Tests.ps1",
    "tests/GitRepositoryWorkflows.Tests.ps1",
    "tests/GitRepositoryStagingWorkflow.Tests.ps1",
    "tests/GitRepositoryBranchWorkflow.Tests.ps1",
    "tests/GitRepositoryStashWorkflow.Tests.ps1",
    "tests/GitRepositoryTagWorkflow.Tests.ps1",
    "tests/GitRepositoryCommitWorkflow.Tests.ps1",
    "tests/GitRepositoryHistoryWorkflow.Tests.ps1",
    "tests/GitRepositoryCherryPickWorkflow.Tests.ps1",
    "tests/GitStagingOperations.Tests.ps1",
    "tests/GitStashOperations.Tests.ps1",
    "tests/GitTagOperations.Tests.ps1",
    "tests/GitConflictAssistant.Tests.ps1",
    "docs/START_HERE.md",
    "docs/METRICS_AND_VALUE_MODEL.md",
    "docs/BRANCH_CLEANUP_ASSISTANT_v3_9_1.md",
    f"docs/RELEASE_NOTES_v{version_string}.md",
    f"docs/SWOT_AND_ROADMAP_v{version_string}.md",
    f"docs/ROADMAP_REVIEW_v{version_string}.md",
    f"docs/ARCHITECTURE_v{version_string}.md",
    f"docs/TECHNICAL_DEBT_REDUCTION_PLAN_v{version_string}.md",
    f"docs/RELEASE_NOTES_v{version_string}.md",
    f"docs/CONFLICT_RESOLUTION_ASSISTANT_v{version_string}.md",
]

require_paths(required)

require_markers(
    "README.md",
    [
        "Why this exists",
        "What makes it different?",
        "Core Features",
        "Current focus: v3.8.1",
        "Stable split-script layout",
    ],
    "README product positioning",
)

require_markers(
    "docs/START_HERE.md",
    [
        "Requirements",
        "Validate the package",
        "If something looks wrong",
        "UI modes",
        "Recovery and Repository State Doctor",
        "History, graph inspection, and branch relationships",
        "Stable split-script layout",
    ],
    "START_HERE onboarding",
)

require_markers(
    "git-glide-gui.bat",
    ["GitGlideGUI.ps1"],
    "stable launcher"
)

require_markers(
    "scripts/windows/smoke-launch.ps1",
    [
        "GitGlideGUI.ps1",
        "-SmokeTest"
    ],
    "stable smoke-launch"
)

require_markers(
    "scripts/windows/GitGlideVersion.ps1",
    [
        "Resolve-GitGlideVersion",
        "Invalid Git Glide GUI version value",
    ],
    "version helper",
)

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

require_markers(
    MAIN_SCRIPT,
    [
        "stable split entrypoint",
        "GitGlideVersion.ps1",
        "Resolve-GitGlideVersion",
        "GitGlideGUI.part01-bootstrap-config.ps1",
        "GitGlideGUI.part06-run.ps1",
        "Split script parts parsed and initialized",
    ],
    "stable wrapper",
)

require_markers(
    "modules/GitGlideGUI.Core/GitConflictAssistant.psm1",
    [
        "Get-GgcaUnmergedFilesCommandPlan",
        "Get-GgcaConflictMarkerScanForText",
        "Get-GgcaCheckoutOursCommandPlan",
        "Get-GgcaCheckoutTheirsCommandPlan",
        "Test-GgcaStageResolvedFileAllowed",
        "Get-GgcaContinueOperationCommandPlan",
        "Get-GgcaAbortOperationCommandPlan",
    ],
    "conflict assistant module",
)

require_markers(
    "tests/GitConflictAssistant.Tests.ps1",
    [
        "GitConflictAssistant command plans",
        "GitConflictAssistant conflict marker scanning",
        "blocks staging when markers remain",
    ],
    "conflict assistant tests",
)

require_markers(
    "modules/GitGlideGUI.Core/GitBranchCleanup.psm1",
    [
        "Get-GgbcFetchPruneCommandPlan",
        "ConvertFrom-GgbcBranchVerboseText",
        "Get-GgbcDeleteLocalBranchCommandPlan",
        "Get-GgbcDeleteRemoteBranchCommandPlan",
        "Format-GgbcBranchCleanupSummary",
    ],
    "branch cleanup module",
)

require_markers(
    "tests/GitBranchCleanup.Tests.ps1",
    [
        "GitBranchCleanup parsing helpers",
        "GitBranchCleanup protection and command plans",
        "GitBranchCleanup recommendation helpers",
    ],
    "branch cleanup tests",
)

combined_split_script = "\n".join(read_text(p) for p in [MAIN_SCRIPT, *PARTS])

split_markers = [
    "Repository State Doctor",
    "Get-RepositoryStateDoctorSnapshot",
    "Show-RepositoryStateDoctor",
    "Show-ConflictMarkerScan",
    "Test-GuiScriptSyntax",
    "Get-GitGlideGuiScriptValidationPaths",
    "Resize-ChangedFilesContextBanner",
    "Changed Files context banner",
    "Conflict markers still present",
    "Workflow checklist",
    "Merge & Publish",
    "Command palette",
    "Simple / Workflow / Expert mode",
    "Set-DiffPreviewText",
    "Get-DiffPreviewLineColor",
    "DiffAddedText",
    "Branch relationships",
    "Show-BranchRelationshipOverview",
    "HistoryRelationshipTextBox",
    "SHUTDOWN_CLEANUP_WARNING",
    "Conflict Resolution Assistant",
    "Refresh-ConflictAssistant",
    "Show-ConflictAssistantSelectedFileScan",
    "Invoke-ConflictAssistantStageResolved",
    "Branch Cleanup Assistant",
    "Refresh-BranchCleanupAssistant",
    "Show-BranchCleanupAssistant",
    "Invoke-BranchCleanupDeleteSelectedLocal",
    "Invoke-BranchCleanupDeleteSelectedRemote",
]

for marker in split_markers:
    if marker not in combined_split_script:
        fail(f"Missing split-script marker: {marker}")

module_markers = {
    "modules/GitGlideGUI.Core/GitBranchOperations.psm1": [
        "Get-GgbWorkflowChecklist",
        "Format-GgbWorkflowChecklist",
        "Get-GgbCleanupMergedBranchCommandPlan",
    ],
    "modules/GitGlideGUI.Core/GitHistoryOperations.psm1": [
        "Get-GghGraphCommandPlan",
        "ConvertFrom-GghCommitLogLine",
        "ConvertTo-GghVisualGraphRows",
        "Get-GghAheadBehindCommandPlan",
        "Get-GghMergeBaseCommandPlan",
        "Get-GghUniqueCommitsCommandPlan",
        "ConvertFrom-GghAheadBehindCount",
        "Get-GghBranchRelationshipStatus",
        "Format-GghBranchRelationshipSummary",
    ],
    "modules/GitGlideGUI.Core/GitConflictRecovery.psm1": [
        "Get-GgrRecoveryGuidance",
        "Get-GgrUnmergedFilesCommandPlan",
        "ConvertFrom-GgrConflictFileList",
        "Format-GgrConflictFileGuidance",
        "ConvertFrom-GgrConflictState",
        "Get-GgrConflictMarkerScan",
        "Get-GgrConflictMarkerScanForFile",
        "Format-GgrConflictMarkerScan",
        "Get-GgrStageResolvedFileCommandPlan",
        "Get-GgrExternalMergeToolCommandPlan",
    ],
    "modules/GitGlideGUI.Core/GitCherryPickOperations.psm1": [
        "Get-GgcpCherryPickCommandPlan",
        "Test-GgcpCommitish",
        "Get-GgcpSelectedCommitFromHistoryLine",
    ],
    "modules/GitGlideGUI.Core/GitHubOperations.psm1": [
        "New-GghubRemoteUrl",
        "Get-GghubPrivacyChecklist",
        "Get-GghubPublishCommandPreview",
        "Get-GghubDefaultRepositoryDescription",
        "Get-GghubRemoteFailureGuidance",
        "Get-GghubRepositoryWebUrl",
        "Get-GghubPullRequestUrlsFromText",
    ],
    "modules/GitGlideGUI.Core/GitLearningGuidance.psm1": [
        "Get-GglOperationGuidance",
        "Get-GglTypicalWorkflowGuide",
        "Stage selected",
        "Cherry-pick",
        "Typical Git workflows",
    ],
}

for rel_path, markers in module_markers.items():
    require_markers(rel_path, markers, "module")

require_markers(
    "tests/GitHistoryOperations.Tests.ps1",
    [
        "Branch relationship helpers",
        "Get-GghAheadBehindCommandPlan",
        "Get-GghMergeBaseCommandPlan",
        "Get-GghUniqueCommitsCommandPlan",
        "ConvertFrom-GghAheadBehindCount",
        "Get-GghBranchRelationshipStatus",
        "Format-GghBranchRelationshipSummary",
    ],
    "history branch relationship tests",
)

require_markers(
    "scripts/windows/run-pester-tests.ps1",
    [
        "Remove-InvalidPathEntriesFromEnvVar",
        "Convert-GitGlideTestsForPester3",
        "Detected Pester 3.x",
    ],
    "Pester runner robustness",
)

forbidden_regression_markers = [
    "GitGlideGUI-v3.4.ps1",
    "GitGlideGUI-v3.6.5.ps1",
    "$dialog.Tag = [string]$sender.Tag",
]

for rel_path in [MAIN_SCRIPT, *PARTS, "git-glide-gui.bat", "scripts/windows/smoke-launch.ps1"]:
    reject_markers(rel_path, forbidden_regression_markers, "regression")

# Versioned runtime implementation files should no longer be part of the package.
for old_script in (ROOT / "scripts/windows").glob("GitGlideGUI-v*.ps1"):
    fail(f"Unexpected versioned runtime script included: {old_script.name}")

# Do not allow unresolved merge conflict markers in the stable GUI implementation.
assert_no_conflict_markers([MAIN_SCRIPT, *PARTS, "scripts/windows/GitGlideVersion.ps1"])

# Technical-debt guard: GUI implementation files should stay below 4000 lines.
assert_line_count_guard([MAIN_SCRIPT, *PARTS], MAX_GUI_SCRIPT_LINES)

print("Static smoke test passed.")
