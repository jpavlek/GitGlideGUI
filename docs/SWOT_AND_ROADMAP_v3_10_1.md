# Git Glide GUI v3.10.1 SWOT and Roadmap

## Theme

v3.10.1 focuses on collapsible panel hosts and layout crowding reduction.

## Strengths

- Reuses the v3.10.0 layout state model instead of adding another ad-hoc layout setting.
- Keeps layout changes reversible.
- Does not affect Git repository state.
- Reduces visual overload on smaller screens.
- Adds tests for core layout behavior.

## Weaknesses

- Still uses WinForms `SplitContainer` rather than true docking.
- Panel host mapping is currently manual.
- Layout controls live in Appearance, which may still become crowded.
- GUI behavioral automation remains limited.

## Opportunities

- Add stackable workspace groups in v3.10.2.
- Add named layout profiles for Simple, Workflow, Expert, Recovery, Metrics, and Release.
- Add keyboard shortcuts for collapse/restore.
- Add future dockable layout simulation without rewriting the product.

## Threats

- Adding too much layout behavior directly to `part05-ui.ps1` could increase UI script pressure.
- Collapsing important panels could confuse beginners if restore controls are not clear.
- More static smoke markers can become brittle if not paired with tests.

## Roadmap

```text
v3.10.1  Collapsible Panel Host
v3.10.2  Stackable Workspace Groups
v3.10.3  Explicit Layout Save/Discard/Profile Polish
v3.10.4  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```
