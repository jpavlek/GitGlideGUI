# Git Glide GUI v3.8.1 Architecture

v3.8.1 keeps the v3.8 branch relationship feature set and reduces release churn by stabilizing runtime script names.

## Runtime entrypoint

```text
scripts/windows/GitGlideGUI.ps1
```

The entrypoint reads the product version from:

```text
VERSION
```

## Stable split parts

```text
scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1
scripts/windows/GitGlideGUI.part02-state-selection.ps1
scripts/windows/GitGlideGUI.part03-previews-basic-ops.ps1
scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1
scripts/windows/GitGlideGUI.part05-ui.ps1
scripts/windows/GitGlideGUI.part06-run.ps1
```

Release ZIP names and release notes can remain versioned, but runtime implementation files should not be renamed for version-only releases.
