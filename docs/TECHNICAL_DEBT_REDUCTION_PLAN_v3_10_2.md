# Git Glide GUI v3.10.2 Technical Debt Reduction Plan

## Theme

Reduce release-trust debt and layout vocabulary debt.

## Reduced in v3.10.2

- Stale current documentation risk.
- Stale metrics report risk.
- Broken legacy launcher artifact risk.
- Parallel `commandOutput` / `liveOutput` vocabulary risk.
- Misleading `ask-on-exit` save-policy naming risk.

## Remaining debt

- Large GUI script parts still contain UI construction and layout adapter behavior.
- Static smoke tests still rely heavily on marker checks.
- Behavioral GUI testing remains limited.
- WinForms splitter layout still has practical limits for future workspace organization.

## Next technical-debt priority

Before or during v3.10.3, extract more layout-host adapter logic away from the largest GUI script parts. A candidate target is:

```text
modules/GitGlideGUI.WinForms/GitLayoutHost.psm1
```

The core module should remain UI-free. The adapter module should own WinForms-specific splitter and collapse behavior.

### Nested panel-host behavior

The current Collapsible Panel Host allows overlapping parent/child panels. This is acceptable, but the behavior should be made explicit in tests and documentation.

Risk:
- Restoring inner panels while an outer parent remains collapsed can confuse users.
- Restore-all ordering may become inconsistent if future panels are added without parent metadata.

Mitigation:
- Add parent/child panel metadata to the canonical panel registry.
- Restore parent panels before child panels.
- Add tests for nested collapse/restore behavior.
