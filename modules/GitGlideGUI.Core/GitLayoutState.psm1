Set-StrictMode -Version Latest

function ConvertTo-GglsPlainHashtable {
    param($Value)

    $hash = @{}
    if ($null -eq $Value) { return $hash }

    if ($Value -is [hashtable]) {
        foreach ($key in $Value.Keys) { $hash[[string]$key] = $Value[$key] }
        return $hash
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { $hash[[string]$key] = $Value[$key] }
        return $hash
    }

    foreach ($prop in @($Value.PSObject.Properties)) {
        if ($null -ne $prop.Name) { $hash[[string]$prop.Name] = $prop.Value }
    }

    return $hash
}

function Test-GglsLayoutSavePolicy {
    param([string]$SavePolicy)

    return @('ask-on-exit', 'always', 'never') -contains ([string]$SavePolicy).ToLowerInvariant()
}

function Get-GglsNormalizedSavePolicy {
    param([string]$SavePolicy = 'ask-on-exit')

    $candidate = ([string]$SavePolicy).Trim().ToLowerInvariant()
    if (Test-GglsLayoutSavePolicy -SavePolicy $candidate) { return $candidate }
    return 'ask-on-exit'
}

function New-GglsPanelState {
    param(
        [string]$Id,
        [string]$DisplayName,
        [string]$Dock = 'fill',
        [double]$Weight = 1.0,
        [int]$Height = 0,
        [string]$SplitterKey = '',
        [int]$SplitterDistance = 0,
        [bool]$Visible = $true,
        [bool]$Collapsed = $false
    )

    return [pscustomobject]@{
        id = $Id
        displayName = $DisplayName
        visible = [bool]$Visible
        collapsed = [bool]$Collapsed
        dock = $Dock
        weight = [double]$Weight
        height = [int]$Height
        splitterKey = $SplitterKey
        splitterDistance = [int]$SplitterDistance
    }
}

function New-GglsDefaultLayoutState {
    param(
        [string]$ActiveProfile = 'workflow',
        [string]$SavePolicy = 'ask-on-exit'
    )

    $workflowPanels = [ordered]@{
        repositoryStatus = New-GglsPanelState -Id 'repositoryStatus' -DisplayName 'Repository status' -Dock 'top' -Weight 0.18 -SplitterKey 'HeaderTopAreaSplitDistance' -SplitterDistance 120
        workflowActions = New-GglsPanelState -Id 'workflowActions' -DisplayName 'Workflow actions' -Dock 'left' -Weight 0.40 -SplitterKey 'TopSplitDistance' -SplitterDistance 650
        commitPreview = New-GglsPanelState -Id 'commitPreview' -DisplayName 'Commit / preview / help' -Dock 'right' -Weight 0.60 -SplitterKey 'CommitPreviewSplitDistance' -SplitterDistance 470
        changedFiles = New-GglsPanelState -Id 'changedFiles' -DisplayName 'Changed Files' -Dock 'left' -Weight 0.35 -SplitterKey 'ContentSplitDistance' -SplitterDistance 430
        diffPreview = New-GglsPanelState -Id 'diffPreview' -DisplayName 'Diff preview' -Dock 'fill' -Weight 0.45 -SplitterKey 'RightSplitDistance' -SplitterDistance 250
        commandOutput = New-GglsPanelState -Id 'commandOutput' -DisplayName 'Live command output' -Dock 'bottom' -Weight 0.20 -Height 220 -SplitterKey 'LogActionSplitDistance' -SplitterDistance 245
        appearanceEditor = New-GglsPanelState -Id 'appearanceEditor' -DisplayName 'Appearance and layout editor' -Dock 'right' -Weight 0.50 -SplitterKey 'AppearanceSplitDistance' -SplitterDistance 280
    }

    $profiles = [ordered]@{
        simple = [pscustomobject]@{ id = 'simple'; displayName = 'Simple'; panels = $workflowPanels }
        workflow = [pscustomobject]@{ id = 'workflow'; displayName = 'Workflow'; panels = $workflowPanels }
        expert = [pscustomobject]@{ id = 'expert'; displayName = 'Expert'; panels = $workflowPanels }
        recovery = [pscustomobject]@{ id = 'recovery'; displayName = 'Recovery'; panels = $workflowPanels }
        metrics = [pscustomobject]@{ id = 'metrics'; displayName = 'Metrics'; panels = $workflowPanels }
        release = [pscustomobject]@{ id = 'release'; displayName = 'Release'; panels = $workflowPanels }
    }

    return [pscustomobject]@{
        schemaVersion = 1
        activeProfile = $ActiveProfile
        savePolicy = (Get-GglsNormalizedSavePolicy -SavePolicy $SavePolicy)
        profiles = $profiles
    }
}

function Get-GglsProfile {
    param($LayoutState, [string]$ProfileName = '')

    if ($null -eq $LayoutState) { return $null }
    $state = ConvertTo-GglsPlainHashtable -Value $LayoutState
    $profiles = ConvertTo-GglsPlainHashtable -Value $state['profiles']
    $name = if ([string]::IsNullOrWhiteSpace($ProfileName)) { [string]$state['activeProfile'] } else { $ProfileName }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'workflow' }
    if ($profiles.ContainsKey($name)) { return $profiles[$name] }
    if ($profiles.ContainsKey('workflow')) { return $profiles['workflow'] }
    return $null
}

function Get-GglsPanelState {
    param($LayoutState, [string]$PanelId, [string]$ProfileName = '')

    $profile = Get-GglsProfile -LayoutState $LayoutState -ProfileName $ProfileName
    if ($null -eq $profile) { return $null }
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']
    if ($panels.ContainsKey($PanelId)) { return $panels[$PanelId] }
    return $null
}

function Merge-GglsLayoutState {
    param($LayoutState, [string]$SavePolicy = '')

    $default = New-GglsDefaultLayoutState
    if ($null -eq $LayoutState) {
        if (-not [string]::IsNullOrWhiteSpace($SavePolicy)) { return Set-GglsLayoutSavePolicy -LayoutState $default -SavePolicy $SavePolicy }
        return $default
    }

    $defaultHash = ConvertTo-GglsPlainHashtable -Value $default
    $sourceHash = ConvertTo-GglsPlainHashtable -Value $LayoutState

    if ($sourceHash.ContainsKey('schemaVersion')) { $defaultHash['schemaVersion'] = [int]$sourceHash['schemaVersion'] }
    if ($sourceHash.ContainsKey('activeProfile') -and -not [string]::IsNullOrWhiteSpace([string]$sourceHash['activeProfile'])) { $defaultHash['activeProfile'] = [string]$sourceHash['activeProfile'] }
    if ($sourceHash.ContainsKey('savePolicy')) { $defaultHash['savePolicy'] = Get-GglsNormalizedSavePolicy -SavePolicy ([string]$sourceHash['savePolicy']) }
    if (-not [string]::IsNullOrWhiteSpace($SavePolicy)) { $defaultHash['savePolicy'] = Get-GglsNormalizedSavePolicy -SavePolicy $SavePolicy }

    if ($sourceHash.ContainsKey('profiles')) {
        $defaultProfiles = ConvertTo-GglsPlainHashtable -Value $defaultHash['profiles']
        $sourceProfiles = ConvertTo-GglsPlainHashtable -Value $sourceHash['profiles']
        foreach ($profileName in $sourceProfiles.Keys) {
            $defaultProfiles[[string]$profileName] = $sourceProfiles[$profileName]
        }
        $defaultHash['profiles'] = $defaultProfiles
    }

    return [pscustomobject]$defaultHash
}

function Set-GglsPanelState {
    param(
        $LayoutState,
        [string]$PanelId,
        [Nullable[bool]]$Visible = $null,
        [Nullable[bool]]$Collapsed = $null,
        [string]$Dock = '',
        [Nullable[double]]$Weight = $null,
        [Nullable[int]]$Height = $null,
        [Nullable[int]]$SplitterDistance = $null,
        [string]$ProfileName = ''
    )

    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    $profile = Get-GglsProfile -LayoutState $state -ProfileName $ProfileName
    if ($null -eq $profile) { return $state }

    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']
    if (-not $panels.ContainsKey($PanelId)) {
        $panels[$PanelId] = New-GglsPanelState -Id $PanelId -DisplayName $PanelId
    }

    $panelHash = ConvertTo-GglsPlainHashtable -Value $panels[$PanelId]
    if ($null -ne $Visible) { $panelHash['visible'] = [bool]$Visible }
    if ($null -ne $Collapsed) { $panelHash['collapsed'] = [bool]$Collapsed }
    if (-not [string]::IsNullOrWhiteSpace($Dock)) { $panelHash['dock'] = $Dock }
    if ($null -ne $Weight) { $panelHash['weight'] = [double]$Weight }
    if ($null -ne $Height) { $panelHash['height'] = [int]$Height }
    if ($null -ne $SplitterDistance) { $panelHash['splitterDistance'] = [int]$SplitterDistance }

    $panels[$PanelId] = [pscustomobject]$panelHash
    $profileHash['panels'] = $panels

    $stateHash = ConvertTo-GglsPlainHashtable -Value $state
    $profiles = ConvertTo-GglsPlainHashtable -Value $stateHash['profiles']
    $profileId = if ([string]::IsNullOrWhiteSpace($ProfileName)) { [string]$stateHash['activeProfile'] } else { $ProfileName }
    if ([string]::IsNullOrWhiteSpace($profileId)) { $profileId = 'workflow' }
    $profiles[$profileId] = [pscustomobject]$profileHash
    $stateHash['profiles'] = $profiles
    return [pscustomobject]$stateHash
}

function Set-GglsLayoutSavePolicy {
    param($LayoutState, [string]$SavePolicy)

    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    $stateHash = ConvertTo-GglsPlainHashtable -Value $state
    $stateHash['savePolicy'] = Get-GglsNormalizedSavePolicy -SavePolicy $SavePolicy
    return [pscustomobject]$stateHash
}

function Update-GglsLayoutStateFromSplitterDistances {
    param(
        $LayoutState,
        [hashtable]$SplitterDistances,
        [string]$ProfileName = ''
    )

    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    if ($null -eq $SplitterDistances) { return $state }

    $profile = Get-GglsProfile -LayoutState $state -ProfileName $ProfileName
    if ($null -eq $profile) { return $state }
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']

    foreach ($panelId in @($panels.Keys)) {
        $panelHash = ConvertTo-GglsPlainHashtable -Value $panels[$panelId]
        $key = [string]$panelHash['splitterKey']
        if (-not [string]::IsNullOrWhiteSpace($key) -and $SplitterDistances.ContainsKey($key)) {
            $panelHash['splitterDistance'] = [int]$SplitterDistances[$key]
            $panels[$panelId] = [pscustomobject]$panelHash
        }
    }

    $profileHash['panels'] = $panels
    $stateHash = ConvertTo-GglsPlainHashtable -Value $state
    $profiles = ConvertTo-GglsPlainHashtable -Value $stateHash['profiles']
    $profileId = if ([string]::IsNullOrWhiteSpace($ProfileName)) { [string]$stateHash['activeProfile'] } else { $ProfileName }
    if ([string]::IsNullOrWhiteSpace($profileId)) { $profileId = 'workflow' }
    $profiles[$profileId] = [pscustomobject]$profileHash
    $stateHash['profiles'] = $profiles
    return [pscustomobject]$stateHash
}

function Format-GglsLayoutSummary {
    param($LayoutState)

    $state = Merge-GglsLayoutState -LayoutState $LayoutState
    $stateHash = ConvertTo-GglsPlainHashtable -Value $state
    $profile = Get-GglsProfile -LayoutState $state
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']

    $lines = @()
    $lines += 'Layout State Model'
    $lines += ('Schema: {0}' -f $stateHash['schemaVersion'])
    $lines += ('Active profile: {0}' -f $stateHash['activeProfile'])
    $lines += ('Save policy: {0}' -f $stateHash['savePolicy'])
    $lines += ''
    $lines += 'Panels:'
    foreach ($id in @($panels.Keys | Sort-Object)) {
        $panel = ConvertTo-GglsPlainHashtable -Value $panels[$id]
        $lines += ('- {0}: visible={1}, collapsed={2}, dock={3}, splitter={4}:{5}' -f $id, $panel['visible'], $panel['collapsed'], $panel['dock'], $panel['splitterKey'], $panel['splitterDistance'])
    }

    return ($lines -join "`r`n")
}

Export-ModuleMember -Function `
    ConvertTo-GglsPlainHashtable, `
    Test-GglsLayoutSavePolicy, `
    Get-GglsNormalizedSavePolicy, `
    New-GglsPanelState, `
    New-GglsDefaultLayoutState, `
    Get-GglsProfile, `
    Get-GglsPanelState, `
    Merge-GglsLayoutState, `
    Set-GglsPanelState, `
    Set-GglsLayoutSavePolicy, `
    Update-GglsLayoutStateFromSplitterDistances, `
    Format-GglsLayoutSummary
