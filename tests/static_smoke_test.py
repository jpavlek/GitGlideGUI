#!/usr/bin/env python3
"""Static smoke tests for the Git Glide GUI v3.6.11 package.

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
    "scripts/windows/GitGlideGUI-v3.6.11.ps1",
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
    "docs/RELEASE_NOTES_v3_6_11.md",
    "docs/SWOT_AND_ROADMAP_v3_6_11.md",
    "docs/ROADMAP_REVIEW_v3_6_11.md",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    print("Missing required files:")
    for p in missing:
        print(" -", p)
    sys.exit(1)

main = (ROOT / "scripts/windows/GitGlideGUI-v3.6.11.ps1").read_text(encoding="utf-8")
for marker in [
    "Git Glide GUI v3.6.11",
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
]:
    if marker not in main:
        print(f"Missing main-script marker: {marker}")
        sys.exit(1)

launcher = (ROOT / "git-glide-gui.bat").read_text(encoding="utf-8")
if "GitGlideGUI-v3.6.11.ps1" not in launcher:
    print("Launcher does not target v3.6.11 script.")
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

print("Static smoke test passed.")
