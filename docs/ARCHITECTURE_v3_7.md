# Git Glide GUI v3.7.0 Architecture

## Entrypoint

`git-glide-gui.bat` launches:

```text
scripts/windows/GitGlideGUI-v3.7.0.ps1
```

The versioned script is now a small split entrypoint. It dot-sources ordered implementation parts:

```text
GitGlideGUI-v3.7.0.part01-bootstrap-config.ps1
GitGlideGUI-v3.7.0.part02-state-selection.ps1
GitGlideGUI-v3.7.0.part03-previews-basic-ops.ps1
GitGlideGUI-v3.7.0.part04-recovery-push-stash-tags.ps1
GitGlideGUI-v3.7.0.part05-ui.ps1
GitGlideGUI-v3.7.0.part06-run.ps1
```

## Rationale

The previous versioned GUI script exceeded 8000 lines. That increased conflict risk, made version bumps repetitive, and made targeted reviews harder. v3.7.0 keeps behavior stable but creates file-level boundaries.

## Current boundaries

- Part 01: bootstrap, module imports, configuration, general utilities, theme helpers.
- Part 02: script variables, logging, repository verification, command execution, selection helpers.
- Part 03: command preview builders, commit preview functions, basic Git operations.
- Part 04: recovery, state doctor, push/merge, stash, tag, commit, and layout utilities.
- Part 05: WinForms UI construction and UI event wiring.
- Part 06: startup flow and `ShowDialog` execution.

## Quality guard

`tests/static_smoke_test.py` fails if any split implementation file exceeds 4000 lines.
