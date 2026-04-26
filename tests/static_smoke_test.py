#!/usr/bin/env python3
"""Static smoke tests for the Git Glide GUI v3.6.13 package.

This test intentionally checks explicit known paths only. It does not use
recursive os.walk, which avoids symlink/network-share traversal problems.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
required = [
    "git-glide-gui.bat",
    "git-flow-gui2.bat",
    "run-quality-checks.bat",
    "run-pester-tests.bat",
    "scripts/windows/GitGlideGUI-v3.6.13.ps1",
    "scripts/windows/smoke-launch.ps1",
    "scripts/windows/run-quality-checks.bat",
    "scripts/windows/run-pester-tests.ps1",
    "scripts/windows/run-scriptanalyzer.ps1",
    "scripts/windows/package-release.ps1",
    "PSScriptAnalyzerSettings.psd1",
    "modules/GitGlideGUI.Core/GitCommandSafety.psm1",
    "modules/GitGlideGUI.Core/GitRepositoryStatus.psm1",
    "modules/GitGlideGUI.Core/GitRepositoryOnboarding.psm1",
    "modules/GitGlideGUI.Core/GitStagingOperations.psm1",
    "modules/GitGlideGUI.Core/GitBranchOperations.psm1",
    "modules/GitGlideGUI.Core/GitStashOperations.psm1",
    "modules/GitGlideGUI.Core/GitTagOperations.psm1",
    "modules/GitGlideGUI.Core/GitCommitOperations.psm1",
    "modules/GitGlideGUI.Core/GitHistoryOperations.psm1",
    "modules/GitGlideGUI.Core/GitConflictRecovery.psm1",
    "modules/GitGlideGUI.Core/GitCherryPickOperations.psm1",
    "modules/GitGlideGUI.Core/GitLearningGuidance.psm1",
    "modules/GitGlideGUI.Core/GitHubOperations.psm1",
    "tests/GitCommandSafety.Tests.ps1",
    "tests/GitRepositoryStatus.Tests.ps1",
    "tests/GitRepositoryInitialization.Tests.ps1",
    "tests/GitRepositoryOnboarding.Tests.ps1",
    "tests/GitRepositoryWorkflows.Tests.ps1",
    "tests/GitStagingOperations.Tests.ps1",
    "tests/GitRepositoryStagingWorkflow.Tests.ps1",
    "tests/GitBranchOperations.Tests.ps1",
    "tests/GitRepositoryBranchWorkflow.Tests.ps1",
    "tests/GitStashOperations.Tests.ps1",
    "tests/GitRepositoryStashWorkflow.Tests.ps1",
    "tests/GitTagOperations.Tests.ps1",
    "tests/GitRepositoryTagWorkflow.Tests.ps1",
    "tests/GitCommitOperations.Tests.ps1",
    "tests/GitRepositoryCommitWorkflow.Tests.ps1",
    "tests/GitHistoryOperations.Tests.ps1",
    "tests/GitRepositoryHistoryWorkflow.Tests.ps1",
    "tests/GitConflictRecovery.Tests.ps1",
    "tests/GitCherryPickOperations.Tests.ps1",
    "tests/GitRepositoryCherryPickWorkflow.Tests.ps1",
    "tests/GitLearningGuidance.Tests.ps1",
    "tests/GitHubOperations.Tests.ps1",
    "docs/START_HERE.md",
    "docs/RELEASE_NOTES_v3_6_12.md",
    "docs/SWOT_AND_ROADMAP_v3_6_12.md",
    "docs/ROADMAP_REVIEW_v3_6_12.md",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    print("Missing required files:")
    for p in missing:
        print(" -", p)
    sys.exit(1)

main = (ROOT / "scripts/windows/GitGlideGUI-v3.6.13.ps1").read_text(encoding="utf-8")
for marker in [
    "Git Glide GUI v3.6.13",
    "GitHubOperations.psm1",
    "GitHub publish...",
    "Get-GggStatusDisplayText",
    "Remove-SelectedFilesFromGitAndDisk",
    "Stop-TrackingSelectedFilesKeepLocal",
    "ConvertFrom-GggTrackedFileList",
    "Browse tracked files",
    "Get-TrackedFileItemsFromGit",
    "Show-TrackedFilesDialog",
    "Build-GitHubDiagnosticsPreview",
    "Show-GitHubRemoteDiagnosticsDialog",
    "GitHub diagnostics...",
    "Merge & Publish",
    "switch anyway",
    "Build-SyncMainIntoDevelopPreview",
    "Merge-SelectedFeatureIntoDevelop",
    "Run-QualityChecksForMergeGate",
    "Show-BranchTrackingOverview",
    "Open-LastPullRequestUrl",
    "Show-GitHubPublishDialog",
    "Build-GitHubPublishPreview",
    "Open-GitHubNewRepositoryPage",
    "Open-GitHubCopilotSettingsPage",
    "Private for proprietary/client/unfinished code",
    "Stage-SelectedConflictFileAsResolved",
    "ContinueOperationButton",
    "ExternalMergeToolTextBox",
    "Launch-ExternalMergeTool",
    "Get-RecoveryStateSnapshot",
    "GitLearningGuidance.psm1",
    "Learning",
    "ConflictFilesListBox",
    "Refresh-ConflictFiles",
    "Open-SelectedConflictFile",
    "Open-SelectedConflictFolder",
    "Get-GgrConflictMarkerScanForFile",
    "Conflict markers still present",
    "HistoryVisualListView",
    "H*=HEAD",
    "Branches",
    "Remotes",
    "Set-CherryPickCommitFromHistorySelection",
    "Use selected for cherry-pick",
    "GitConflictRecovery.psm1",
    "GitCherryPickOperations.psm1",
    "GitHistoryOperations.psm1",
    "Recovery",
    "History / Graph",
    "[switch]$SmokeTest",
    "Command palette",
    "Simple / Workflow / Expert mode",
    "Build-MergeWorkflowChecklistPreview",
    "Cleanup-SelectedFeatureBranch",
    "Clean merged branch",
    "Workflow checklist",
    "Get-UiModeTabPages",
    "Work area / Changed files",
]:
    if marker not in main:
        print(f"Missing main-script marker: {marker}")
        sys.exit(1)

launcher = (ROOT / "git-glide-gui.bat").read_text(encoding="utf-8")
if "GitGlideGUI-v3.6.13.ps1" not in launcher:
    print("Launcher does not target v3.6.13 script.")
    sys.exit(1)


branch_module = (ROOT / "modules/GitGlideGUI.Core/GitBranchOperations.psm1").read_text(encoding="utf-8")
for marker in ["Get-GgbWorkflowChecklist", "Format-GgbWorkflowChecklist", "Get-GgbCleanupMergedBranchCommandPlan"]:
    if marker not in branch_module:
        print(f"Missing branch workflow marker: {marker}")
        sys.exit(1)

history_module = (ROOT / "modules/GitGlideGUI.Core/GitHistoryOperations.psm1").read_text(encoding="utf-8")
for marker in ["Get-GghGraphCommandPlan", "ConvertFrom-GghCommitLogLine", "ConvertTo-GghVisualGraphRows"]:
    if marker not in history_module:
        print(f"Missing history module marker: {marker}")
        sys.exit(1)

recovery_module = (ROOT / "modules/GitGlideGUI.Core/GitConflictRecovery.psm1").read_text(encoding="utf-8")
for marker in ["Get-GgrRecoveryGuidance", "Get-GgrUnmergedFilesCommandPlan", "ConvertFrom-GgrConflictFileList", "Format-GgrConflictFileGuidance", "ConvertFrom-GgrConflictState", "Get-GgrConflictMarkerScan", "Get-GgrConflictMarkerScanForFile", "Format-GgrConflictMarkerScan", "Get-GgrStageResolvedFileCommandPlan", "Get-GgrExternalMergeToolCommandPlan"]:
    if marker not in recovery_module:
        print(f"Missing recovery module marker: {marker}")
        sys.exit(1)

cherry_module = (ROOT / "modules/GitGlideGUI.Core/GitCherryPickOperations.psm1").read_text(encoding="utf-8")
for marker in ["Get-GgcpCherryPickCommandPlan", "Test-GgcpCommitish", "Get-GgcpSelectedCommitFromHistoryLine"]:
    if marker not in cherry_module:
        print(f"Missing cherry-pick module marker: {marker}")
        sys.exit(1)

github_module = (ROOT / "modules/GitGlideGUI.Core/GitHubOperations.psm1").read_text(encoding="utf-8")
for marker in ["New-GghubRemoteUrl", "Get-GghubPrivacyChecklist", "Get-GghubPublishCommandPreview", "Get-GghubDefaultRepositoryDescription", "Get-GghubRemoteFailureGuidance", "Get-GghubRepositoryWebUrl", "Get-GghubPullRequestUrlsFromText"]:
    if marker not in github_module:
        print(f"Missing GitHub module marker: {marker}")
        sys.exit(1)

learning_module = (ROOT / "modules/GitGlideGUI.Core/GitLearningGuidance.psm1").read_text(encoding="utf-8")
for marker in ["Get-GglOperationGuidance", "Get-GglTypicalWorkflowGuide", "Stage selected", "Cherry-pick", "Typical Git workflows"]:
    if marker not in learning_module:
        print(f"Missing learning module marker: {marker}")
        sys.exit(1)

pester_runner = (ROOT / "scripts/windows/run-pester-tests.ps1").read_text(encoding="utf-8")
for marker in ["Remove-InvalidPathEntriesFromEnvVar", "Convert-GitGlideTestsForPester3", "Detected Pester 3.x"]:
    if marker not in pester_runner:
        print(f"Missing Pester runner robustness marker: {marker}")
        sys.exit(1)

for forbidden in ["GitGlideGUI-v3.4.ps1", "GitGlideGUI-v3.6.5.ps1", "$dialog.Tag = [string]$sender.Tag"]:
    if forbidden in main or forbidden in launcher:
        print("Forbidden regression marker found:", forbidden)
        sys.exit(1)


version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
if version != "3.6.13":
    print(f"VERSION mismatch: expected 3.6.13, got {version!r}")
    sys.exit(1)

import json
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
if manifest.get("version") != version:
    print("manifest.json version does not match VERSION.")
    sys.exit(1)
expected_script = f"scripts/windows/GitGlideGUI-v{version}.ps1"
if manifest.get("main_script") != expected_script:
    print(f"manifest main_script mismatch: expected {expected_script}, got {manifest.get('main_script')!r}")
    sys.exit(1)
if not (ROOT / expected_script).exists():
    print(f"Expected versioned main script missing: {expected_script}")
    sys.exit(1)

version_markers = {
    "git-glide-gui.bat": f"GitGlideGUI-v{version}.ps1",
    "scripts/windows/smoke-launch.ps1": f"GitGlideGUI-v{version}.ps1",
    "scripts/windows/run-quality-checks.bat": f"Git Glide GUI v{version} quality checks",
    "README.md": "v3.6.13",
    "docs/START_HERE.md": "v3.6.13",
}
for rel_path, marker in version_markers.items():
    text = (ROOT / rel_path).read_text(encoding="utf-8", errors="replace")
    if marker not in text:
        print(f"Version consistency marker missing in {rel_path}: {marker}")
        sys.exit(1)

for old_script in ROOT.joinpath("scripts/windows").glob("GitGlideGUI-v*.ps1"):
    if old_script.name != f"GitGlideGUI-v{version}.ps1":
        print(f"Unexpected old versioned main script included: {old_script.name}")
        sys.exit(1)

print("Static smoke test passed.")
