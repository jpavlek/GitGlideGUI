# Git Glide GUI v3.10.2 Roadmap Review

## Current milestone

v3.10.2 implements release hygiene, quality-gate hardening, and layout-host consistency.

This was the correct priority before stackable workspace groups because v3.10.1 revealed release trust issues: stale docs, stale metrics, and mismatched layout panel vocabulary.

## Included

- v3.10.2 metadata and current documentation alignment
- metrics refresh before static smoke checks
- static smoke checks for stale metrics/docs and missing launcher references
- removal of stale v3.7 launcher artifacts
- canonical panel registry in the Layout State Model
- legacy `commandOutput` to `liveOutput` normalization
- visible `manual` save policy with legacy `ask-on-exit` normalization

## Excluded

- stackable workspace groups
- full docking simulation
- drag-and-drop layout editing
- multi-monitor workspace profiles

## Recommended next sequence

```text
v3.10.3  Stackable Workspace Groups
v3.10.4  Explicit Layout Save/Discard/Profile Polish
v3.10.5  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```

- **Nested panel-host semantics**: document and test parent/child layout behavior. `topWorkflow` contains `repositoryStatus`, and `diffAndOutput` contains `diffPreview` and `liveOutput`. Future restore-all behavior should restore outer containers before inner containers and make hidden-child behavior explicit.
