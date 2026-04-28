$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitConflictAssistant.psm1'
Import-Module $modulePath -Force

Describe 'GitConflictAssistant command plans' {
    It 'builds a read-only unmerged files command plan' {
        $plan = Get-GgcaUnmergedFilesCommandPlan
        $plan.FileName | Should Be 'git'
        $plan.CommandLine | Should Match 'diff'
        $plan.RiskLevel | Should Be 'read-only'
    }
    It 'builds ours and theirs command plans with confirmation' {
        $ours = Get-GgcaCheckoutOursCommandPlan -Path 'src/file.txt'
        $theirs = Get-GgcaCheckoutTheirsCommandPlan -Path 'src/file.txt'
        $ours.Destructive | Should Be $true
        $theirs.Destructive | Should Be $true
        $ours.CommandLine | Should Match '--ours'
        $theirs.CommandLine | Should Match '--theirs'
    }
    It 'rejects unsafe paths' {
        { Get-GgcaCheckoutOursCommandPlan -Path "bad`npath.txt" } | Should Throw
    }
}

Describe 'GitConflictAssistant conflict marker scanning' {
    It 'detects a complete conflict marker block' {
        $text = @'
before
<<<<<<< HEAD
ours
=======
theirs
>>>>>>> feature
after
'@
        $scan = Get-GgcaConflictMarkerScanForText -Text $text -Path 'file.txt'
        $scan.HasMarkers | Should Be $true
        $scan.BlockCount | Should Be 1
        $scan.IncompleteCount | Should Be 0
    }
    It 'blocks staging when markers remain' {
        $text = @'
<<<<<<< HEAD
ours
=======
theirs
>>>>>>> feature
'@
        $scan = Get-GgcaConflictMarkerScanForText -Text $text -Path 'file.txt'
        $decision = Test-GgcaStageResolvedFileAllowed -Scan $scan
        $decision.Allowed | Should Be $false
        $decision.Reason | Should Match 'Conflict markers still present'
    }
    It 'allows staging when markers are absent' {
        $scan = Get-GgcaConflictMarkerScanForText -Text 'resolved content' -Path 'file.txt'
        $decision = Test-GgcaStageResolvedFileAllowed -Scan $scan
        $decision.Allowed | Should Be $true
    }
}

Describe 'GitConflictAssistant parsing' {
    It 'parses unmerged file list' {
        $items = ConvertFrom-GgcaUnmergedFileList -Text "a.txt`nb/c.txt`n"
        @($items).Count | Should Be 2
        $items[0].Path | Should Be 'a.txt'
    }
}
