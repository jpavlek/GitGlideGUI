$ErrorActionPreference = 'Stop'

Describe 'Git Glide GUI repository initialization workflow' {
    It 'can initialize a temporary folder with the configured main branch using Git directly' {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) { Set-ItResult -Skipped -Because 'git is not installed'; return }

        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('git-glide-init-test-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            $result = & git -C $tempRoot init -b main 2>&1
            if ($LASTEXITCODE -ne 0) {
                & git -C $tempRoot init | Out-Null
                & git -C $tempRoot branch -M main | Out-Null
            }
            $inside = & git -C $tempRoot rev-parse --is-inside-work-tree
            $branch = & git -C $tempRoot branch --show-current
            $inside | Should -Be 'true'
            $branch | Should -Be 'main'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
