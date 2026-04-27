# scripts/windows/GitGlideVersion.ps1
# Shared version helper for Git Glide GUI scripts.

function Resolve-GitGlideVersion {
    param(
        [string]$RepositoryRoot,
        [string]$ExplicitVersion = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitVersion)) {
        $version = $ExplicitVersion.Trim()
    } else {
        $versionPath = Join-Path $RepositoryRoot 'VERSION'
        if (Test-Path -LiteralPath $versionPath) {
            $version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
        } else {
            $version = ''
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = '0.0.0-dev'
    }

    if ($version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$' -and $version -ne '0.0.0-dev') {
        throw "Invalid Git Glide GUI version value: $version"
    }

    return $version
}