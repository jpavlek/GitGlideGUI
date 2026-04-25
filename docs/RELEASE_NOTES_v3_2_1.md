# Git Glide GUI v3.5 - Shutdown Stability Hotfix

## Fixed

- Fixed a WinForms shutdown regression where closing the app could show a .NET JIT debugging dialog with:

```text
System.Management.Automation.PipelineStoppedException: The pipeline has been stopped.
```

## Root cause

The `FormClosing` event called PowerShell cleanup logic directly. On some Windows PowerShell/WinForms shutdown paths, the host pipeline can already be stopping while the form-closing delegate is still invoked. If `PipelineStoppedException` escapes from that delegate, WinForms treats it as an unhandled exception and shows the JIT debugging dialog.

## Change

- Close-time cleanup is now best-effort and non-throwing.
- `PipelineStoppedException` is swallowed during shutdown.
- Layout persistence still runs when possible.
- Running Git operations are asked to cancel during close.
- Top-level `ShowDialog()` handling no longer reports normal pipeline shutdown as an app crash.

## Validation

- Static package smoke test updated for v3.5.
- Windows smoke-launch script updated to target `GitGlideGUI-v3.5.ps1`.
