# Git Glide GUI v3.10.1 Technical Debt Reduction Plan

## Current debt focus

v3.10.1 reduces layout usability debt but increases pressure on GUI adapter code.

## Debt reduced

- Collapsed panel state is modeled in the UI-free layout state module.
- Collapse/restore behavior is centralized through panel host helpers.
- Close-time modal layout prompts are removed from the shutdown path.
- The nested quality-check launcher is restored.

## Debt still present

- Panel host mappings are manual.
- `part05-ui.ps1` remains a large UI construction file.
- GUI behavioral tests are still limited.
- Static smoke tests still rely on marker strings.

## Guardrails

- Keep each split script under 4000 lines.
- Keep core model behavior in `GitLayoutState.psm1`.
- Keep WinForms-specific behavior in GUI adapter functions.
- Do not add modal dialogs to FormClosing.

## Next reduction target

v3.10.2 should introduce stackable workspace groups so related panels can share space instead of forcing every tool into the same fixed layout.
