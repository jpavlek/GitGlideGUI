$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitLayoutState.psm1'
Import-Module $modulePath -Force

Describe 'GitLayoutState default model' {
    It 'creates a default workflow layout state with save policy' {
        $state = New-GglsDefaultLayoutState -ActiveProfile 'workflow' -SavePolicy 'ask-on-exit'

        $state.schemaVersion | Should Be 1
        $state.activeProfile | Should Be 'workflow'
        $state.savePolicy | Should Be 'ask-on-exit'
        $panel = Get-GglsPanelState -LayoutState $state -PanelId 'changedFiles'
        $panel.displayName | Should Be 'Changed Files'
        $panel.splitterKey | Should Be 'ContentSplitDistance'
    }

    It 'normalizes invalid save policies to ask-on-exit' {
        Get-GglsNormalizedSavePolicy -SavePolicy 'always' | Should Be 'always'
        Get-GglsNormalizedSavePolicy -SavePolicy 'never' | Should Be 'never'
        Get-GglsNormalizedSavePolicy -SavePolicy 'invalid' | Should Be 'ask-on-exit'
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
        (Get-GglsPanelState -LayoutState $updated -PanelId 'diffPreview').splitterDistance | Should Be 300
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
