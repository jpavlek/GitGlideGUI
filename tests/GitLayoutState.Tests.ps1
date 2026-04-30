$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitLayoutState.psm1'
Import-Module $modulePath -Force

Describe 'GitLayoutState default model' {
    It 'creates a default workflow layout state with manual save policy' {
        $state = New-GglsDefaultLayoutState -ActiveProfile 'workflow' -SavePolicy 'manual'

        $state.schemaVersion | Should Be 1
        $state.activeProfile | Should Be 'workflow'
        $state.savePolicy | Should Be 'manual'
        $panel = Get-GglsPanelState -LayoutState $state -PanelId 'changedFiles'
        $panel.displayName | Should Be 'Changed Files'
        $panel.splitterKey | Should Be 'ContentSplitDistance'
    }
	
	It 'normalizes invalid and legacy save policies to manual' {
        Test-GglsLayoutSavePolicy -SavePolicy 'manual' | Should Be $true
        Test-GglsLayoutSavePolicy -SavePolicy 'ask-on-exit' | Should Be $true
    
        Get-GglsNormalizedSavePolicy -SavePolicy 'manual' | Should Be 'manual'
        Get-GglsNormalizedSavePolicy -SavePolicy 'always' | Should Be 'always'
        Get-GglsNormalizedSavePolicy -SavePolicy 'never' | Should Be 'never'
        Get-GglsNormalizedSavePolicy -SavePolicy 'ask-on-exit' | Should Be 'manual'
        Get-GglsNormalizedSavePolicy -SavePolicy 'invalid' | Should Be 'manual'
    }
}

Describe 'GitLayoutState panel updates' {
    It 'updates panel visibility, collapsed state, dock preference, and splitter distance' {
        $state = New-GglsDefaultLayoutState
        $updated = Set-GglsPanelState `
            -LayoutState $state `
            -PanelId 'changedFiles' `
            -Visible $true `
            -Collapsed $true `
            -Dock 'left' `
            -Weight 0.25 `
            -SplitterDistance 360

        $panel = Get-GglsPanelState -LayoutState $updated -PanelId 'changedFiles'
        $panel.collapsed | Should Be $true
        $panel.dock | Should Be 'left'
        $panel.weight | Should Be 0.25
        $panel.splitterDistance | Should Be 360
    }

    It 'updates splitter distances from current GUI splitter values' {
        $state = New-GglsDefaultLayoutState
        $distances = @{
            ContentSplitDistance = 512
            RightSplitDistance = 300
        }

        $updated = Update-GglsLayoutStateFromSplitterDistances -LayoutState $state -SplitterDistances $distances

        (Get-GglsPanelState -LayoutState $updated -PanelId 'changedFiles').splitterDistance | Should Be 512
        (Get-GglsPanelState -LayoutState $updated -PanelId 'diffAndOutput').splitterDistance | Should Be 512
        (Get-GglsPanelState -LayoutState $updated -PanelId 'diffPreview').splitterDistance | Should Be 300
    }

    It 'canonicalizes legacy commandOutput to liveOutput' {
        $state = New-GglsDefaultLayoutState
        $updated = Set-GglsPanelCollapsed -LayoutState $state -PanelId 'commandOutput' -Collapsed $true

        Get-GglsPanelCollapsed -LayoutState $updated -PanelId 'liveOutput' | Should Be $true
        (Get-GglsPanelState -LayoutState $updated -PanelId 'commandOutput').id | Should Be 'liveOutput'
    }
}

Describe 'GitLayoutState summary' {
    It 'formats a readable layout summary' {
        $state = Set-GglsLayoutSavePolicy -LayoutState (New-GglsDefaultLayoutState) -SavePolicy 'never'
        $summary = Format-GglsLayoutSummary -LayoutState $state

        $summary | Should Match 'Layout State Model'
        $summary | Should Match 'Save policy: never'
        $summary | Should Match 'changedFiles'
    }
}

Describe 'GitLayoutState collapsible panels' {
    It 'toggles panel collapsed state' {
        $state = New-GglsDefaultLayoutState
        $collapsed = Set-GglsPanelCollapsed -LayoutState $state -PanelId 'changedFiles' -Collapsed $true
        Get-GglsPanelCollapsed -LayoutState $collapsed -PanelId 'changedFiles' | Should Be $true

        $restored = Toggle-GglsPanelCollapsed -LayoutState $collapsed -PanelId 'changedFiles'
        Get-GglsPanelCollapsed -LayoutState $restored -PanelId 'changedFiles' | Should Be $false
    }

    It 'preserves last splitter distance' {
        $state = New-GglsDefaultLayoutState
        $updated = Set-GglsPanelLastSize -LayoutState $state -PanelId 'diffPreview' -LastSplitterDistance 333
        Get-GglsPanelLastSize -LayoutState $updated -PanelId 'diffPreview' | Should Be 333
    }

    It 'formats a collapsible panel host summary' {
        $state = Set-GglsPanelCollapsed -LayoutState (New-GglsDefaultLayoutState) -PanelId 'liveOutput' -Collapsed $true
        $summary = Format-GglsPanelHostSummary -LayoutState $state

        $summary | Should Match 'Collapsible Panel Host'
        $summary | Should Match 'liveOutput'
        $summary | Should Match 'collapsed=True'
    }

    It 'lists the canonical layout-host panel IDs used by the GUI adapter' {
        $ids = Get-GglsKnownPanelIds -LayoutState (New-GglsDefaultLayoutState)

        $ids -contains 'topWorkflow' | Should Be $true
        $ids -contains 'diffAndOutput' | Should Be $true
        $ids -contains 'liveOutput' | Should Be $true
    }
}
