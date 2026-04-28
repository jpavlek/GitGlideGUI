# Git Glide GUI v3.9.0 Release Notes

## Theme

Guided conflict resolution assistant.

## Added

- Conflict assistant core module with command-plan helpers.
- Conflict marker scanner for text and files.
- Stage-resolved decision helper that blocks staging while conflict markers remain.
- Ours/theirs command plans with explicit destructive-risk metadata.
- Operation-aware continue and abort command plans for merge, cherry-pick, and rebase.
- Conflict assistant documentation.

## Risk managed

- The first milestone does not attempt automatic conflict resolution.
- Destructive file-level choices require confirmation.
- Stage-resolved is blocked while conflict markers remain.
- Commands remain transparent and previewable.

## Technical-debt context

v3.9.0 adds a high-value workflow without rewriting the full WinForms layout. The next GUI architecture milestone should modularize panels into collapsible, dockable, stackable, persistent layout widgets.
