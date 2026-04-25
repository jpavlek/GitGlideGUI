# Git Glide GUI v2.8.1 - Startup Choice Dialog Hotfix

## Why this release exists

A real Windows test of v2.7 revealed that the repository startup choice dialog could throw repeated PowerShell errors when the user clicked one of the choice buttons:

```text
The property 'Tag' cannot be found on this object. Verify that the property exists and can be set.
You cannot call a method on a null-valued expression.
```

The same fragile event-handler pattern was still present in v2.8, so this hotfix is based on v2.8 and fixes the issue there.

## Root cause

The startup dialog used a nested helper function that attached button click handlers referencing `$dialog` from an outer scope:

```powershell
$button.Add_Click({ param($sender, $eventArgs) $dialog.Tag = [string]$sender.Tag; $dialog.Close() }.GetNewClosure())
```

On Windows PowerShell/WinForms, this can fail because the click handler does not reliably resolve the expected local `$dialog` instance from the nested helper function context.

## Fix

v2.8.1 now stores the selected startup action in explicit script-scoped startup-dialog state:

```powershell
$script:RepositoryStartupChoiceDialogResult
$script:RepositoryStartupChoiceDialogForm
```

The choice button captures only the immutable choice value and closes the known dialog form safely.

## Additional UI improvement

The startup dialog is now larger, DPI-scaled, and resizable:

```text
960 x 540 default size
820 x 460 minimum size
Sizable form border
DPI autoscaling
```

This should reduce clipping like the screenshot showed when explanatory cards are displayed.

## Validation

Static checks verify that:

- the launcher targets `GitGlideGUI-v2.8.1.ps1`
- the hotfix markers exist
- the fragile `$dialog.Tag = [string]$sender.Tag` handler is no longer present

Live validation still needs Windows 10/11 with Git installed.
