$module = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitLearningGuidance.psm1'
Import-Module $module -Force

Describe 'GitLearningGuidance module' {
    It 'lists common beginner operations' {
        $names = Get-GglOperationGuidanceNames
        $names | Should -Contain 'Stage selected'
        $names | Should -Contain 'Cherry-pick'
        $names | Should -Contain 'Resolve conflicts'
    }

    It 'explains operations in plain language' {
        $text = Get-GglOperationGuidance -Name 'Commit'
        $text | Should -Match 'Records staged changes'
        $text | Should -Match 'Useful when'
    }

    It 'explains typical workflows' {
        $workflow = Get-GglTypicalWorkflowGuide
        $workflow | Should -Match 'Typical Git workflows'
        $workflow | Should -Match 'Create a feature branch'
        $workflow | Should -Match 'Release'
    }
}
