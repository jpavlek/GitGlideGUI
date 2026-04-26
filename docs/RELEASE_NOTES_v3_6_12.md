# Git Glide GUI v3.6.12 Release Notes

## Focus

v3.6.12 improves GUI organization and progressive disclosure so Git Glide can keep its features without overwhelming the user.

## Added

- Three UI modes: **Simple**, **Workflow**, and **Expert**.
- Simple mode keeps everyday actions visible.
- Workflow mode exposes guided Git Flow, Recovery, History, Tags, and Learning.
- Expert mode shows every tool, including Custom Git and Appearance.
- Command Palette entry point for finding hidden actions without crowding the main screen.
- Mode-aware changed-files context banner above the file list.
- Clearer Work area / Changed files section naming.

## Safety

No Git workflow functionality was intentionally removed. Advanced features are hidden only by UI mode and remain reachable through Workflow/Expert mode or the Command Palette.

## Validation

Static smoke test and package integrity checks should be run from a freshly extracted ZIP. Windows validation should run `scripts\windows\run-quality-checks.bat`.
