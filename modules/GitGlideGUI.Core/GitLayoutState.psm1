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

function Test-GglsMapContainsKey {
    param(
        $Map,
        [string]$Key
    )

    if ($null -eq $Map) {
        return $false
    }

    if ($Map -is [System.Collections.IDictionary]) {
        return $Map.Contains($Key)
    }

    try {
        return @($Map.PSObject.Properties.Name) -contains $Key
    } catch {
        return $false
    }
}

function Test-GglsLayoutSavePolicy {
    param([string]$SavePolicy)

    $candidate = ([string]$SavePolicy).Trim().ToLowerInvariant()
    return @('manual', 'always', 'never', 'ask-on-exit') -contains $candidate
}

function Get-GglsNormalizedSavePolicy {
    param([string]$SavePolicy = 'manual')

    $candidate = ([string]$SavePolicy).Trim().ToLowerInvariant()
    if ($candidate -eq 'ask-on-exit') { return 'manual' }
    if (@('manual', 'always', 'never') -contains $candidate) { return $candidate }
    return 'manual'
}

function Get-GglsCanonicalPanelId {
    param([string]$PanelId)

    $candidate = ([string]$PanelId).Trim()
    switch ($candidate.ToLowerInvariant()) {
        'repositorystatus' { return 'repositoryStatus' }
        'topworkflow' { return 'topWorkflow' }
        'workflowactions' { return 'workflowActions' }
        'commitpreview' { return 'commitPreview' }
        'changedfiles' { return 'changedFiles' }
        'diffandoutput' { return 'diffAndOutput' }
        'diffpreview' { return 'diffPreview' }
        'liveoutput' { return 'liveOutput' }
        'commandoutput' { return 'liveOutput' }
        'appearanceeditor' { return 'appearanceEditor' }
        default { return $candidate }
    }
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
        [int]$LastSplitterDistance = 0,
        [bool]$Visible = $true,
        [bool]$Collapsed = $false
    )

    $canonicalId = Get-GglsCanonicalPanelId -PanelId $Id
    $effectiveLastSplitterDistance = if ([int]$LastSplitterDistance -gt 0) { [int]$LastSplitterDistance } else { [int]$SplitterDistance }

    return [pscustomobject]@{
        id = $canonicalId
        displayName = $DisplayName
        visible = [bool]$Visible
        collapsed = [bool]$Collapsed
        dock = $Dock
        weight = [double]$Weight
        height = [int]$Height
        splitterKey = $SplitterKey
        splitterDistance = [int]$SplitterDistance
        lastSplitterDistance = $effectiveLastSplitterDistance
    }
}

function Get-GglsCanonicalPanelRegistry {
    $panels = [ordered]@{}
    $panels.repositoryStatus = New-GglsPanelState -Id 'repositoryStatus' -DisplayName 'Repository status' -Dock 'top' -Weight 0.18 -SplitterKey 'HeaderTopAreaSplitDistance' -SplitterDistance 120
    $panels.topWorkflow = New-GglsPanelState -Id 'topWorkflow' -DisplayName 'Top workflow area' -Dock 'top' -Weight 0.42 -SplitterKey 'MainWorkSplitDistance' -SplitterDistance 470
    $panels.workflowActions = New-GglsPanelState -Id 'workflowActions' -DisplayName 'Workflow actions' -Dock 'left' -Weight 0.40 -SplitterKey 'TopSplitDistance' -SplitterDistance 650
    $panels.commitPreview = New-GglsPanelState -Id 'commitPreview' -DisplayName 'Commit / preview / help' -Dock 'right' -Weight 0.60 -SplitterKey 'CommitPreviewSplitDistance' -SplitterDistance 470
    $panels.changedFiles = New-GglsPanelState -Id 'changedFiles' -DisplayName 'Changed Files' -Dock 'left' -Weight 0.35 -SplitterKey 'ContentSplitDistance' -SplitterDistance 430
    $panels.diffAndOutput = New-GglsPanelState -Id 'diffAndOutput' -DisplayName 'Diff and output area' -Dock 'right' -Weight 0.65 -SplitterKey 'ContentSplitDistance' -SplitterDistance 430
    $panels.diffPreview = New-GglsPanelState -Id 'diffPreview' -DisplayName 'Diff preview' -Dock 'fill' -Weight 0.45 -SplitterKey 'RightSplitDistance' -SplitterDistance 250
    $panels.liveOutput = New-GglsPanelState -Id 'liveOutput' -DisplayName 'Live command output' -Dock 'bottom' -Weight 0.20 -Height 220 -SplitterKey 'RightSplitDistance' -SplitterDistance 245
	$panels.appearanceEditor = New-GglsPanelState -Id 'appearanceEditor' -DisplayName 'Appearance and layout editor' -Dock 'right' -Weight 0.50 -SplitterKey 'AppearanceSplitDistance' -SplitterDistance 280
    return $panels
}

function New-GglsProfile {
    param([string]$Id, [string]$DisplayName)
    return [pscustomobject]@{ id = $Id; displayName = $DisplayName; panels = (Get-GglsCanonicalPanelRegistry) }
}

function New-GglsDefaultLayoutState {
    param(
        [string]$ActiveProfile = 'workflow',
        [string]$SavePolicy = 'manual'
    )

    $profiles = [ordered]@{
        simple = New-GglsProfile -Id 'simple' -DisplayName 'Simple'
        workflow = New-GglsProfile -Id 'workflow' -DisplayName 'Workflow'
        expert = New-GglsProfile -Id 'expert' -DisplayName 'Expert'
        recovery = New-GglsProfile -Id 'recovery' -DisplayName 'Recovery'
        metrics = New-GglsProfile -Id 'metrics' -DisplayName 'Metrics'
        release = New-GglsProfile -Id 'release' -DisplayName 'Release'
    }

    return [pscustomobject]@{
        schemaVersion = 1
        activeProfile = $ActiveProfile
        savePolicy = (Get-GglsNormalizedSavePolicy -SavePolicy $SavePolicy)
        profiles = $profiles
    }
}

function Merge-GglsPanelTable {
    param($DefaultPanels, $SourcePanels)

    $merged = [ordered]@{}
    $defaultPanelTable = ConvertTo-GglsPlainHashtable -Value $DefaultPanels

	foreach ($key in @($defaultPanelTable.Keys | Sort-Object)) {
		$canonical = Get-GglsCanonicalPanelId -PanelId $key
		$merged[$canonical] = ConvertTo-GglsPlainHashtable -Value $defaultPanelTable[$key]
	}

    $source = ConvertTo-GglsPlainHashtable -Value $SourcePanels
    foreach ($key in @($source.Keys)) {
        $canonical = Get-GglsCanonicalPanelId -PanelId $key
        $sourcePanel = ConvertTo-GglsPlainHashtable -Value $source[$key]

        if (Test-GglsMapContainsKey -Map $sourcePanel -Key 'id') {
            $canonical = Get-GglsCanonicalPanelId -PanelId ([string]$sourcePanel['id'])
        }

        $base = @{}
        if (Test-GglsMapContainsKey -Map $merged -Key $canonical) {
            $base = ConvertTo-GglsPlainHashtable -Value $merged[$canonical]
        }

        foreach ($prop in $sourcePanel.Keys) {
			$base[$prop] = $sourcePanel[$prop]
		}

		$base['id'] = $canonical

		if (-not (Test-GglsMapContainsKey -Map $base -Key 'displayName') -or [string]::IsNullOrWhiteSpace([string]$base['displayName'])) {
            $base['displayName'] = $canonical
        }

        if (-not (Test-GglsMapContainsKey -Map $base -Key 'visible')) {
            $base['visible'] = $true
        }

        if (-not (Test-GglsMapContainsKey -Map $base -Key 'collapsed')) {
            $base['collapsed'] = $false
        }

        $merged[$canonical] = $base
    }

    $result = [ordered]@{}
    foreach ($key in @($merged.Keys)) {
		$result[$key] = [pscustomobject]$merged[$key]
	}

	return $result
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

    $canonicalPanelId = Get-GglsCanonicalPanelId -PanelId $PanelId
    $profile = Get-GglsProfile -LayoutState $LayoutState -ProfileName $ProfileName
    if ($null -eq $profile) { return $null }
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']
    if ($panels.ContainsKey($canonicalPanelId)) { return $panels[$canonicalPanelId] }
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
            $sourceProfileHash = ConvertTo-GglsPlainHashtable -Value $sourceProfiles[$profileName]
            $defaultProfileHash = @{}
            if ($defaultProfiles.ContainsKey($profileName)) { $defaultProfileHash = ConvertTo-GglsPlainHashtable -Value $defaultProfiles[$profileName] }
            foreach ($prop in $sourceProfileHash.Keys) {
                if ($prop -ne 'panels') { $defaultProfileHash[$prop] = $sourceProfileHash[$prop] }
            }
            if (-not $defaultProfileHash.ContainsKey('id')) { $defaultProfileHash['id'] = [string]$profileName }
            if (-not $defaultProfileHash.ContainsKey('displayName')) { $defaultProfileHash['displayName'] = [string]$profileName }
            $defaultPanels = if ($defaultProfileHash.ContainsKey('panels')) { $defaultProfileHash['panels'] } else { (Get-GglsCanonicalPanelRegistry) }
            $sourcePanels = if ($sourceProfileHash.ContainsKey('panels')) { $sourceProfileHash['panels'] } else { @{} }
            $defaultProfileHash['panels'] = Merge-GglsPanelTable -DefaultPanels $defaultPanels -SourcePanels $sourcePanels
            $defaultProfiles[[string]$profileName] = [pscustomobject]$defaultProfileHash
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
        [Nullable[int]]$LastSplitterDistance = $null,
        [string]$ProfileName = ''
    )

    $canonicalPanelId = Get-GglsCanonicalPanelId -PanelId $PanelId
    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    $profile = Get-GglsProfile -LayoutState $state -ProfileName $ProfileName
    if ($null -eq $profile) { return $state }

    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']
    if (-not $panels.ContainsKey($canonicalPanelId)) {
        $panels[$canonicalPanelId] = New-GglsPanelState -Id $canonicalPanelId -DisplayName $canonicalPanelId
    }

    $panelHash = ConvertTo-GglsPlainHashtable -Value $panels[$canonicalPanelId]
    $panelHash['id'] = $canonicalPanelId
    if ($null -ne $Visible) { $panelHash['visible'] = [bool]$Visible }
    if ($null -ne $Collapsed) { $panelHash['collapsed'] = [bool]$Collapsed }
    if (-not [string]::IsNullOrWhiteSpace($Dock)) { $panelHash['dock'] = $Dock }
    if ($null -ne $Weight) { $panelHash['weight'] = [double]$Weight }
    if ($null -ne $Height) { $panelHash['height'] = [int]$Height }
    if ($null -ne $SplitterDistance) { $panelHash['splitterDistance'] = [int]$SplitterDistance }
    if ($null -ne $LastSplitterDistance) { $panelHash['lastSplitterDistance'] = [int]$LastSplitterDistance }

    $panels[$canonicalPanelId] = [pscustomobject]$panelHash
    $profileHash['panels'] = $panels

    $stateHash = ConvertTo-GglsPlainHashtable -Value $state
    $profiles = ConvertTo-GglsPlainHashtable -Value $stateHash['profiles']
    $profileId = if ([string]::IsNullOrWhiteSpace($ProfileName)) { [string]$stateHash['activeProfile'] } else { $ProfileName }
    if ([string]::IsNullOrWhiteSpace($profileId)) { $profileId = 'workflow' }
    $profiles[$profileId] = [pscustomobject]$profileHash
    $stateHash['profiles'] = $profiles
    return [pscustomobject]$stateHash
}

function Get-GglsKnownPanelIds {
    param($LayoutState, [string]$ProfileName = '')

    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    $profile = Get-GglsProfile -LayoutState $state -ProfileName $ProfileName
    if ($null -eq $profile) { return @() }
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']
    return @($panels.Keys | Sort-Object)
}

function Get-GglsPanelCollapsed {
    param($LayoutState, [string]$PanelId, [string]$ProfileName = '')

    $panel = Get-GglsPanelState -LayoutState $LayoutState -PanelId $PanelId -ProfileName $ProfileName
    if ($null -eq $panel) { return $false }
    $panelHash = ConvertTo-GglsPlainHashtable -Value $panel
    if ($panelHash.ContainsKey('collapsed')) { return [bool]$panelHash['collapsed'] }
    return $false
}

function Set-GglsPanelCollapsed {
    param(
        $LayoutState,
        [string]$PanelId,
        [bool]$Collapsed,
        [string]$ProfileName = ''
    )

    return Set-GglsPanelState -LayoutState $LayoutState -PanelId (Get-GglsCanonicalPanelId -PanelId $PanelId) -Collapsed $Collapsed -Visible (-not $Collapsed) -ProfileName $ProfileName
}

function Toggle-GglsPanelCollapsed {
    param($LayoutState, [string]$PanelId, [string]$ProfileName = '')

    $current = Get-GglsPanelCollapsed -LayoutState $LayoutState -PanelId $PanelId -ProfileName $ProfileName
    return Set-GglsPanelCollapsed -LayoutState $LayoutState -PanelId $PanelId -Collapsed (-not $current) -ProfileName $ProfileName
}

function Set-GglsPanelLastSize {
    param(
        $LayoutState,
        [string]$PanelId,
        [int]$LastSplitterDistance,
        [string]$ProfileName = ''
    )

    return Set-GglsPanelState -LayoutState $LayoutState -PanelId (Get-GglsCanonicalPanelId -PanelId $PanelId) -LastSplitterDistance $LastSplitterDistance -ProfileName $ProfileName
}

function Get-GglsPanelLastSize {
    param($LayoutState, [string]$PanelId, [string]$ProfileName = '')

    $panel = Get-GglsPanelState -LayoutState $LayoutState -PanelId $PanelId -ProfileName $ProfileName
    if ($null -eq $panel) { return 0 }
    $panelHash = ConvertTo-GglsPlainHashtable -Value $panel
    if ($panelHash.ContainsKey('lastSplitterDistance')) { return [int]$panelHash['lastSplitterDistance'] }
    if ($panelHash.ContainsKey('splitterDistance')) { return [int]$panelHash['splitterDistance'] }
    return 0
}

function Format-GglsPanelHostSummary {
    param($LayoutState, [string]$ProfileName = '')

    $state = if ($null -eq $LayoutState) { New-GglsDefaultLayoutState } else { Merge-GglsLayoutState -LayoutState $LayoutState }
    $profile = Get-GglsProfile -LayoutState $state -ProfileName $ProfileName
    $profileHash = ConvertTo-GglsPlainHashtable -Value $profile
    $panels = ConvertTo-GglsPlainHashtable -Value $profileHash['panels']

    $lines = @()
    $lines += 'Collapsible Panel Host'
    $lines += ('Profile: {0}' -f $(if ([string]::IsNullOrWhiteSpace($ProfileName)) { $state.activeProfile } else { $ProfileName }))
    $lines += ''
    foreach ($id in @($panels.Keys | Sort-Object)) {
        $panel = ConvertTo-GglsPlainHashtable -Value $panels[$id]
        $last = if ($panel.ContainsKey('lastSplitterDistance')) { [int]$panel['lastSplitterDistance'] } else { [int]$panel['splitterDistance'] }
        $lines += ('- {0}: collapsed={1}, visible={2}, lastSize={3}' -f $id, $panel['collapsed'], $panel['visible'], $last)
    }
    return ($lines -join "`r`n")
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
            $panelHash['lastSplitterDistance'] = [int]$SplitterDistances[$key]
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
        $last = if ($panel.ContainsKey('lastSplitterDistance')) { [int]$panel['lastSplitterDistance'] } else { [int]$panel['splitterDistance'] }
        $lines += ('- {0}: visible={1}, collapsed={2}, dock={3}, splitter={4}:{5}, lastSize={6}' -f $id, $panel['visible'], $panel['collapsed'], $panel['dock'], $panel['splitterKey'], $panel['splitterDistance'], $last)
    }

    return ($lines -join "`r`n")
}

Export-ModuleMember -Function `
    ConvertTo-GglsPlainHashtable, `
    Test-GglsLayoutSavePolicy, `
    Get-GglsNormalizedSavePolicy, `
    Get-GglsCanonicalPanelId, `
    Get-GglsCanonicalPanelRegistry, `
    New-GglsPanelState, `
    New-GglsDefaultLayoutState, `
    Get-GglsProfile, `
    Get-GglsPanelState, `
    Merge-GglsLayoutState, `
    Set-GglsPanelState, `
    Get-GglsKnownPanelIds, `
    Get-GglsPanelCollapsed, `
    Set-GglsPanelCollapsed, `
    Toggle-GglsPanelCollapsed, `
    Set-GglsPanelLastSize, `
    Get-GglsPanelLastSize, `
    Format-GglsPanelHostSummary, `
    Set-GglsLayoutSavePolicy, `
    Update-GglsLayoutStateFromSplitterDistances, `
    Format-GglsLayoutSummary
