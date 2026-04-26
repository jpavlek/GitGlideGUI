# This file is part of Git Glide GUI v3.8.0 split-script architecture.
# It is dot-sourced by GitGlideGUI-v3.8.0.ps1.

# Initialize and show
Set-HelpExamples
Append-Log -Text 'Git Glide GUI - Enhanced Version v3.8.0 ready.' -Color ([System.Drawing.Color]::DarkGreen)
Append-Log -Text "Config: $script:ConfigPath" -Color ([System.Drawing.Color]::DarkGray)
Append-Log -Text "Audit log: $script:AuditLogPath" -Color ([System.Drawing.Color]::DarkGray)
Write-AuditLog -Message ("STARTUP | RepoRoot='{0}' | Version=v3.8.0" -f $script:RepoRoot)

$repositoryReady = Ensure-RepositorySelected -InitialStartup

if ($script:StartupAborted) {
    Write-AuditLog -Message 'STARTUP_ABORTED | User closed repository choice dialog'
    exit 0
}

Apply-UiMode
Set-CommandPreview -Title 'Welcome to Git Glide GUI v3.8.0' -Commands 'Hover a button to preview its commands.' -Notes 'Use Setup for repository setup, UI mode, command palette, and GitHub publish/diagnostics guidance. Simple mode keeps everyday actions visible, Workflow mode shows Git Flow steps, and Expert mode shows every tool. Use Integrate for Merge & Publish workflows, Recovery for the State Doctor/conflicts, and History / Graph for branch inspection. Press ESC to cancel running operations.'
if ($repositoryReady) { Refresh-Status } else { Set-SuggestedNextAction -Text 'Open existing repo or init new repo before running Git operations.' -Action 'choose-repo' }

try {
    [void]$form.ShowDialog()
} catch [System.Management.Automation.PipelineStoppedException] {
    # Normal host/pipeline shutdown path. Avoid showing a crash dialog.
    exit 0
} catch {
    $message = 'Git Glide GUI crashed: ' + $_.Exception.Message
    try {
        Append-Log -Text $message -Color ([System.Drawing.Color]::Firebrick)
    } catch {}
    try {
        [System.Windows.Forms.MessageBox]::Show($message, 'Git Glide GUI failed', 'OK', 'Error') | Out-Null
    } catch {}
    exit 1
}
