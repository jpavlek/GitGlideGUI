#!/usr/bin/env python3
"""Static smoke tests for the Git Glide GUI package.

This test intentionally checks explicit known paths and release consistency.
It avoids recursive os.walk, which prevents symlink/network-share traversal
problems, while still guarding against incomplete packages, stale launchers,
unresolved merge markers, and oversized GUI implementation files.
"""

from pathlib import Path
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
MAX_GUI_SCRIPT_LINES = 4000


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
    fail(f"VERSION is not a semantic version like 3.7.0: {version!r}")

manifest = json.loads(read_text("manifest.json"))

main_script = manifest.get("main_script")
expected_main_script = f"scripts/windows/GitGlideGUI-v{version}.ps1"

if manifest.get("version") != version:
    fail(f"manifest.json version mismatch: VERSION={version!r}, manifest={manifest.get('version')!r}")

if main_script != expected_main_script:
    fail(f"manifest main_script mismatch: expected {expected_main_script}, got {main_script!r}")

if not (ROOT / main_script).exists():
    fail(f"Expected versioned main script missing: {main_script}")


# v3.7+ split script layout.
versioned_prefix = f"GitGlideGUI-v{version}."
part_files = sorted(
    p.relative_to(ROOT).as_posix()
    for p in (ROOT / "scripts/windows").glob(f"GitGlideGUI-v{version}.part*.ps1")
)

if len(part_files) != 6:
    fail(f"Expected 6 split script part files for v{version}, found {len(part_files)}: {part_files}")

expected_part_suffixes = [
    "part01-bootstrap-config.ps1",
    "part02-state-selection.ps1",
    "part03-previews-basic-ops.ps1",
    "part04-recovery-push-stash-tags.ps1",
    "part05-ui.ps1",
    "part06-run.ps1",
]

for suffix in expected_part_suffixes:
    expected = f"scripts/windows/{versioned_prefix}{suffix}"
    if expected not in part_files:
        fail(f"Missing split script part: {expected}")


required = [
    "README.md",
    "VERSION",
    "manifest.json",
    "git-glide-gui.bat",
    "git-flow-gui2.bat",
    "run-quality-checks.bat",
    "run-pester-tests.bat",
    "PSScriptAnalyzerSettings.psd1",
    main_script,
    *part_files,
    "scripts/windows/smoke-launch.ps1",
    "scripts/windows/run-quality-checks.bat",
    "scripts/windows/run-pester-tests.ps1",
    "scripts/windows/run-scriptanalyzer.ps1",
    "scripts/windows/init-gitglide-repo.ps1",
    "scripts/windows/package-release.ps1",
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
    "tests/GitBranchOperations.Tests.ps1",
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
    "docs/START_HERE.md",
    "docs/RELEASE_NOTES_v3_7.md",
    "docs/SWOT_AND_ROADMAP_v3_7.md",
    "docs/ROADMAP_REVIEW_v3_7.md",
    "docs/ARCHITECTURE_v3_7.md",
    "docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_7.md",
]

require_paths(required)


launcher = read_text("git-glide-gui.bat")
if f"GitGlideGUI-v{version}.ps1" not in launcher:
    fail(f"Launcher does not target v{version} script.")

require_markers(
    "scripts/windows/smoke-launch.ps1",
    [
        "VERSION",
        "GitGlideGUI-v$version.ps1",
        "-SmokeTest",
    ],
    "smoke-launch version-driven launcher",
)

wrapper_markers = [
    "Split entrypoint",
    f"GitGlideGUI-v{version}.part01-bootstrap-config.ps1",
    f"GitGlideGUI-v{version}.part06-run.ps1",
    "Split script parts parsed and initialized",
]
require_markers(main_script, wrapper_markers, "wrapper")


combined_split_script = "\n".join(read_text(p) for p in [main_script, *part_files])

split_markers = [
    f"Git Glide GUI v{version}",
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

for rel_path in [main_script, *part_files, "git-glide-gui.bat", "scripts/windows/smoke-launch.ps1"]:
    reject_markers(rel_path, forbidden_regression_markers, "regression")


# Do not allow unresolved merge conflict markers in the versioned GUI implementation.
assert_no_conflict_markers([main_script, *part_files])


# v3.7 technical-debt guard: GUI implementation files should stay below 4000 lines.
assert_line_count_guard([main_script, *part_files], MAX_GUI_SCRIPT_LINES)


# Keep stale versioned monolithic GUI scripts out of release packages.
# Split part files for the current version are allowed.
for old_script in (ROOT / "scripts/windows").glob("GitGlideGUI-v*.ps1"):
    name = old_script.name
    if name == f"GitGlideGUI-v{version}.ps1":
        continue
    if name.startswith(f"GitGlideGUI-v{version}.part") and name.endswith(".ps1"):
        continue
    fail(f"Unexpected old versioned main script included: {name}")


print("Static smoke test passed.")
