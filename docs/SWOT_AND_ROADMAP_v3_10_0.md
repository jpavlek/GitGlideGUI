# Git Glide GUI v3.10.0 SWOT and Roadmap

## Theme

v3.10.0 focuses on modular layout state and explicit layout persistence.

## Strengths

- Layout state becomes testable and inspectable.
- Existing WinForms layout remains functional.
- Users gain control over save-on-exit behavior.
- The model prepares the product for collapsible, stackable, and dockable panels.

## Weaknesses

- Full docking is not implemented yet.
- `part05-ui.ps1` remains large.
- GUI behavioral tests are still limited.

## Opportunities

- Add collapsible panel hosts in v3.10.1.
- Add stackable workspace groups in v3.10.2.
- Add dockable layout simulation in v3.10.3.
- Add named layout profiles for Simple, Workflow, Expert, Recovery, Metrics, and Release workflows.

## Threats

- Adding more workflow panels before layout modularization could overload the interface.
- Direct WinForms manipulation can remain brittle if reusable panel abstractions are delayed.

## Roadmap

```text
v3.10.0  Modular Layout State Model
v3.10.1  Collapsible Panel Host
v3.10.2  Stackable Workspace Groups
v3.10.3  Dockable Layout Simulation
v3.11.0  CI/CD and Pull Request Integration
```
