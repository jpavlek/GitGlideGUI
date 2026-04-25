# Git Glide GUI v3.5 - SWOT and roadmap note

## Strengths improved

- Quality checks now better support older Windows PowerShell environments with Pester 3.4.0.
- The test runner no longer treats collection containment as file-content checks in Pester 3.
- More generated command plans are verified through temporary repository workflows.

## Weaknesses reduced

- The quality gate was previously sensitive to installed Pester version differences.
- Several tests validated the right product behavior but used assertions that were not portable across Pester versions.

## Opportunities

- Keep building the visual graph only after the quality gate is stable.
- Add a small self-test command inside the GUI later so users can validate their environment without opening scripts.

## Threats

- Windows PowerShell 5.1 plus old Pester versions remain common on developer machines.
- Future tests must avoid Pester-version-specific syntax unless the compatibility converter supports it.

## Roadmap impact

This is a stabilization hotfix, not a feature release. It should precede v3.5 because the visual History / Graph tab will need reliable parsing and history tests.
