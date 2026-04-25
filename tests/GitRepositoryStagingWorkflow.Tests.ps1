# Temporary repository integration tests for staging workflows.
$stagingModule = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitStagingOperations.psm1'
$statusModule = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitRepositoryStatus.psm1'
Import-Module $stagingModule -Force
Import-Module $statusModule -Force

function New-TempGitRepositoryForStaging {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-StagingTest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    git -C $root init -b main *> $null
    if ($LASTEXITCODE -ne 0) {
        git -C $root init *> $null
        git -C $root branch -M main *> $null
    }
    git -C $root config user.email 'git-glide-gui-tests@example.invalid' *> $null
    git -C $root config user.name 'Git Glide GUI Tests' *> $null
    Set-Content -LiteralPath (Join-Path $root 'file.txt') -Value 'one' -Encoding UTF8
    git -C $root add -A *> $null
    git -C $root commit -m 'Initial commit' *> $null
    return $root
}

Describe 'Git Glide staging workflow integration' {
    It 'stages selected file via command plan' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepositoryForStaging
        try {
            Set-Content -LiteralPath (Join-Path $repo 'file.txt') -Value 'two' -Encoding UTF8
            $snapshot = Get-GfgRepositoryStatus -RepositoryPath $repo
            $item = @($snapshot.Items | Where-Object { $_.Path -eq 'file.txt' })[0]
            $plan = (Get-GggStageSelectedCommandPlan -Items @($item))[0]
            $args = @('-C', $repo) + @($plan.Arguments)
            & git @args *> $null
            $after = Get-GfgRepositoryStatus -RepositoryPath $repo
            $after.Summary.Staged | Should -Be 1
            $after.Summary.Unstaged | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'unstages selected file via command plan' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepositoryForStaging
        try {
            Set-Content -LiteralPath (Join-Path $repo 'file.txt') -Value 'two' -Encoding UTF8
            git -C $repo add file.txt *> $null
            $snapshot = Get-GfgRepositoryStatus -RepositoryPath $repo
            $item = @($snapshot.Items | Where-Object { $_.Path -eq 'file.txt' })[0]
            $plan = (Get-GggUnstageSelectedCommandPlan -Items @($item))[0]
            $args = @('-C', $repo) + @($plan.Arguments)
            & git @args *> $null
            $after = Get-GfgRepositoryStatus -RepositoryPath $repo
            $after.Summary.Staged | Should -Be 0
            $after.Summary.Unstaged | Should -Be 1
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'unstages a newly added file before the first commit using rm cached' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-StagingUnbornTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        try {
            git -C $repo init -b main *> $null
            if ($LASTEXITCODE -ne 0) {
                git -C $repo init *> $null
                git -C $repo branch -M main *> $null
            }
            Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value 'draft' -Encoding UTF8
            git -C $repo add README.md *> $null
            $snapshot = Get-GfgRepositoryStatus -RepositoryPath $repo
            $item = @($snapshot.Items | Where-Object { $_.Path -eq 'README.md' })[0]
            $plan = (Get-GggUnstageSelectedCommandPlan -Items @($item) -RepositoryHasNoCommits)[0]
            $plan.Arguments | Should -Be @('rm','--cached','--','README.md')
            $commandArgs = @('-C', $repo) + @($plan.Arguments)
            & git @commandArgs *> $null
            $LASTEXITCODE | Should Be 0
            $after = Get-GfgRepositoryStatus -RepositoryPath $repo
            $after.Summary.Staged | Should -Be 0
            Test-Path -LiteralPath (Join-Path $repo 'README.md') | Should -BeTrue
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

}
