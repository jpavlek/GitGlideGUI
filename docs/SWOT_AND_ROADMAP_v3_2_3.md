# Git Glide GUI v3.5 SWOT / Roadmap Update

v3.5 improves release quality by making the Pester runner compatible with both older Windows PowerShell/Pester 3.x environments and newer Pester versions.

## Strength improved

Quality checks are now more likely to run on real developer machines without requiring immediate PowerShell module upgrades.

## Weakness reduced

The project previously assumed newer Pester behavior. That made the quality-check pipeline brittle on machines with Pester 3.4.0.

## Roadmap impact

No strategic roadmap change is needed. This reinforces the existing roadmap item: quality gates and CI/test reliability before larger visual features.

## Next priority

v3.5 should continue with a first read-only History / Graph tab, a dedicated history service, merge-aware history parsing tests, and then conflict-resolution and cherry-pick workflows.
