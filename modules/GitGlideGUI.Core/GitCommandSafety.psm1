# GitGlideGUI.Core - Git command safety helpers
# PowerShell 5.1 compatible. Keep this module UI-free so it can be tested without WinForms.

Set-StrictMode -Version 2.0

function ConvertTo-GfgQuotedArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    # Windows command-line quoting compatible with CommandLineToArgvW / C runtime parsing.
    # Backslashes before a quote or final closing quote must be doubled.
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0

    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') {
            $backslashes++
            continue
        }

        if ($ch -eq '"') {
            if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
            [void]$builder.Append('\"')
            $backslashes = 0
            continue
        }

        if ($backslashes -gt 0) {
            [void]$builder.Append(('\' * $backslashes))
            $backslashes = 0
        }
        [void]$builder.Append($ch)
    }

    if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Format-GfgGitCommandArgs {
    param([object[]]$Arguments)
    if (-not $Arguments -or @($Arguments).Count -eq 0) { return 'git <arguments>' }
    return 'git ' + (($Arguments | ForEach-Object { ConvertTo-GfgQuotedArgument ([string]$_) }) -join ' ')
}

function Convert-GfgGitCommandTextToArgs {
    param([string]$CommandText)

    if ([string]::IsNullOrWhiteSpace($CommandText)) { return @() }

    $text = $CommandText.Trim()
    if ($text -match "[`r`n]") {
        throw 'Enter one git command only. Multi-line shell scripts are intentionally not supported here.'
    }

    $args = New-Object System.Collections.Generic.List[string]
    $buffer = New-Object System.Text.StringBuilder
    $quote = [char]0
    $escaped = $false

    foreach ($ch in $text.ToCharArray()) {
        if ($escaped) {
            [void]$buffer.Append($ch)
            $escaped = $false
            continue
        }
        if ($quote -eq '"' -and $ch -eq '\') {
            $escaped = $true
            continue
        }
        if ($quote -ne [char]0) {
            if ($ch -eq $quote) {
                $quote = [char]0
            } else {
                [void]$buffer.Append($ch)
            }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
            continue
        }
        if ([char]::IsWhiteSpace($ch)) {
            if ($buffer.Length -gt 0) {
                [void]$args.Add($buffer.ToString())
                [void]$buffer.Clear()
            }
            continue
        }
        [void]$buffer.Append($ch)
    }

    if ($quote -ne [char]0) { throw 'Unclosed quote in custom git command.' }
    if ($escaped) { [void]$buffer.Append('\') }
    if ($buffer.Length -gt 0) { [void]$args.Add($buffer.ToString()) }

    $arr = @($args.ToArray())
    if ($arr.Count -gt 0 -and $arr[0] -ieq 'git') { $arr = @($arr | Select-Object -Skip 1) }
    if ($arr.Count -ge 2 -and $arr[0] -eq '-C') { $arr = @($arr | Select-Object -Skip 2) }

    if ($arr.Count -eq 0) { return @() }
    foreach ($token in $arr) {
        if ($token -in @('&&','||',';','|','>','>>','<')) {
            throw 'Shell operators are intentionally not supported. Enter only git arguments, for example: status -sb'
        }
    }

    return $arr
}

function Test-GfgCustomGitArgsAllowed {
    param(
        [object[]]$Arguments,
        [string[]]$AllowedSubcommands = @()
    )

    $arr = @($Arguments)
    if ($arr.Count -eq 0) { return $true }
    $subcommand = ([string]$arr[0]).ToLowerInvariant()
    $allowed = @($AllowedSubcommands)
    if ($allowed.Count -eq 0) {
        $allowed = @('status','log','diff','show','branch','checkout','switch','add','reset','restore','stash','push','pull','fetch','merge','rebase','cherry-pick','tag','remote','reflog','blame','clean','mv','rm')
    }
    $allowedLower = @($allowed | ForEach-Object { ([string]$_).ToLowerInvariant() })
    if ($allowedLower -notcontains $subcommand) {
        throw "Custom Git subcommand '$subcommand' is not enabled. Use a supported git subcommand or add it deliberately to SafeCustomGitSubcommands in GitGlideGUI-Config.json."
    }
    return $true
}

function Test-GfgGitArgsPotentiallyDestructive {
    param([object[]]$Arguments)

    $arr = @($Arguments | ForEach-Object { [string]$_ })
    if ($arr.Count -eq 0) { return $false }
    $sub = $arr[0].ToLowerInvariant()
    $lower = @($arr | ForEach-Object { $_.ToLowerInvariant() })
    $joined = ' ' + ($lower -join ' ') + ' '

    if ($sub -eq 'reset' -and ($joined -match ' --hard( |$)' -or $joined -match ' --merge( |$)' -or $joined -match ' --keep( |$)')) { return $true }
    if ($sub -eq 'clean') { return $true }
    if ($sub -eq 'push' -and ($joined -match ' --force( |$)' -or $joined -match ' -f( |$)' -or $joined -match ' --delete( |$)' -or $joined -match ' :')) { return $true }
    if ($sub -eq 'branch' -and ($joined -match ' -d( |$)' -or $joined -match ' -d ' -or $joined -match ' --delete( |$)')) { return $true }
    if ($sub -eq 'tag' -and ($joined -match ' -d( |$)' -or $joined -match ' --delete( |$)' -or $joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'stash' -and ($joined -match ' drop( |$)' -or $joined -match ' clear( |$)' -or $joined -match ' pop( |$)')) { return $true }
    if ($sub -eq 'checkout' -and ($joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'switch' -and ($joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'restore') { return $true }
    if ($sub -eq 'rm') { return $true }
    if ($sub -eq 'rebase') { return $true }
    return $false
}

function Test-GfgGitRefName {
    param(
        [string]$Name,
        [string]$Kind = 'reference'
    )

    if ([string]::IsNullOrWhiteSpace($Name)) { return @{ Valid = $false; Error = "$Kind name cannot be empty." } }
    if ($Name -match '\s') { return @{ Valid = $false; Error = "$Kind name cannot contain spaces." } }
    if ($Name -match '[~^:?*\[\]\\]') { return @{ Valid = $false; Error = "$Kind name contains invalid Git reference characters." } }
    if ($Name -match '\.\.|^\.|\.$|/$|//|\.lock$|^-' ) { return @{ Valid = $false; Error = "$Kind name format is invalid for a Git reference." } }
    return @{ Valid = $true }
}

Export-ModuleMember -Function `
    ConvertTo-GfgQuotedArgument, `
    Format-GfgGitCommandArgs, `
    Convert-GfgGitCommandTextToArgs, `
    Test-GfgCustomGitArgsAllowed, `
    Test-GfgGitArgsPotentiallyDestructive, `
    Test-GfgGitRefName
