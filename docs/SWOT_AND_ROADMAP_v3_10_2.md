# Git Glide GUI v3.10.2 SWOT and Roadmap

## Strengths

- Stronger release hygiene: current docs, manifest, metrics, and version now agree.
- Better quality gate: stale metrics and missing launcher-script references are detectable.
- Cleaner layout vocabulary: the core model now knows the same practical panel IDs used by the Collapsible Panel Host.
- More honest save-policy naming: `manual` reflects actual explicit-save behavior better than `ask-on-exit`.

## Weaknesses

- WinForms layout adapter logic is still inside large GUI script parts.
- Static smoke tests remain marker-heavy and should eventually be complemented by more behavioral GUI tests.
- True docking and stackable workspaces are still future work.

## Opportunities

- Build stackable workspace groups on top of a cleaner panel registry.
- Add commit-planning and change-grouping for AI-assisted development.
- Use metrics and release consistency checks as a visible product trust signal.

## Threats

- Adding more UI panels without extraction will increase maintenance pressure.
- Competing Git GUIs remain visually more polished.
- If release artifacts drift again, the product's trust story weakens quickly.

## Recommended next sequence

```text
v3.10.3  Stackable Workspace Groups
v3.10.4  Explicit Layout Save/Discard/Profile Polish
v3.10.5  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```
