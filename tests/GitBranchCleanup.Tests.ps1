$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitBranchCleanup.psm1'
Import-Module $modulePath -Force

Describe 'GitBranchCleanup parsing helpers' {
    It 'parses git branch -vv lines with upstream status' {
        $line = '* feature/example abc1234 [origin/feature/example: ahead 1, behind 2] commit subject'

        $item = ConvertFrom-GgbcBranchVerboseLine -Line $line

        $item | Should Not Be $null
        $item.Name | Should Be 'feature/example'
        $item.Hash | Should Be 'abc1234'
        $item.IsCurrent | Should Be $true
        $item.Upstream | Should Be 'origin/feature/example'
        $item.UpstreamStatus | Should Be 'ahead 1, behind 2'
        $item.Subject | Should Be 'commit subject'
    }

    It 'parses git branch -vv lines without upstream status' {
        $line = '  feature/local-only abc1234 local only commit'

        $item = ConvertFrom-GgbcBranchVerboseLine -Line $line

        $item | Should Not Be $null
        $item.Name | Should Be 'feature/local-only'
        $item.IsCurrent | Should Be $false
        $item.Upstream | Should Be ''
        $item.UpstreamStatus | Should Be ''
        $item.Subject | Should Be 'local only commit'
    }

    It 'parses remote branches and skips origin HEAD aliases' {
        $text = "  origin/HEAD -> origin/main`n  origin/main`n  origin/feature/demo"

        $items = @(ConvertFrom-GgbcRemoteBranchText -Text $text -RemoteName 'origin')

        $items.Count | Should Be 2
        $items[0].Name | Should Be 'main'
        $items[1].Name | Should Be 'feature/demo'
    }

    It 'parses merged branch lists' {
        $text = "  develop`n* main`n  feature/done"

        $items = @(ConvertFrom-GgbcMergedBranchText -Text $text)

        $items -contains 'feature/done' | Should Be $true
        $items -contains 'main' | Should Be $true
    }
}

Describe 'GitBranchCleanup protection and command plans' {
    It 'protects main, develop, release, hotfix, and current branches' {
        Test-GgbcProtectedBranch -BranchName 'main' | Should Be $true
        Test-GgbcProtectedBranch -BranchName 'develop' | Should Be $true
        Test-GgbcProtectedBranch -BranchName 'release/v1' | Should Be $true
        Test-GgbcProtectedBranch -BranchName 'hotfix/urgent' | Should Be $true
        Test-GgbcProtectedBranch -BranchName 'feature/current' -CurrentBranch 'feature/current' | Should Be $true
        Test-GgbcProtectedBranch -BranchName 'feature/old' | Should Be $false
    }

    It 'builds a fetch prune command plan' {
        $plan = Get-GgbcFetchPruneCommandPlan

        $plan.CommandLine | Should Be 'git fetch origin --prune'
        $plan.Risk | Should Be 'network-read'
    }

    It 'builds a safe local delete plan for non-protected branches' {
        $plan = Get-GgbcDeleteLocalBranchCommandPlan -BranchName 'feature/done'

        $plan.CommandLine | Should Be 'git branch -d feature/done'
        $plan.RequiresConfirmation | Should Be $true
    }

    It 'builds a remote delete plan and normalizes origin prefix' {
        $plan = Get-GgbcDeleteRemoteBranchCommandPlan -BranchName 'origin/feature/done'

        $plan.CommandLine | Should Be 'git push origin --delete feature/done'
        $plan.RequiresConfirmation | Should Be $true
    }

    It 'rejects protected branch deletion' {
        { Get-GgbcDeleteLocalBranchCommandPlan -BranchName 'main' } | Should Throw
        { Get-GgbcDeleteRemoteBranchCommandPlan -BranchName 'origin/develop' } | Should Throw
    }

    It 'rejects unsafe branch names' {
        Test-GgbcSafeBranchName -BranchName 'feature/good-name' | Should Be $true
        Test-GgbcSafeBranchName -BranchName '../bad' | Should Be $false
        Test-GgbcSafeBranchName -BranchName '-bad' | Should Be $false
        Test-GgbcSafeBranchName -BranchName 'bad branch' | Should Be $false
    }
}

Describe 'GitBranchCleanup recommendation helpers' {
    It 'recommends safe delete when branch is merged into main' {
        $candidate = Get-GgbcBranchCleanupCandidate `
            -BranchName 'feature/done' `
            -MergedIntoMain @('feature/done') `
            -RemoteBranches @('feature/done')

        $candidate.Recommendation | Should Be 'safe-delete'
        $candidate.MergedIntoMain | Should Be $true
    }

    It 'recommends wait or review when merged into develop but not main' {
        $candidate = Get-GgbcBranchCleanupCandidate `
            -BranchName 'feature/wait' `
            -MergedIntoDevelop @('feature/wait') `
            -RemoteBranches @('feature/wait')

        $candidate.Recommendation | Should Be 'wait-or-review'
    }

    It 'formats a branch cleanup summary' {
        $candidates = @(
            Get-GgbcBranchCleanupCandidate `
                -BranchName 'feature/old-finished' `
                -MergedIntoMain @('feature/old-finished') `
                -MergedIntoDevelop @('feature/old-finished') `
                -RemoteBranches @('feature/old-finished') `
                -MainBranch 'main' `
                -BaseBranch 'develop' `
                -CurrentBranch 'main'
        )

        $summary = Format-GgbcBranchCleanupSummary -Candidates $candidates -RemoteCandidates @()

        $summary | Should Match 'feature/old-finished'
        $summary | Should Match 'safe'
    }
}