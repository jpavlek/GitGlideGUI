# Technical Debt Reduction Plan v3.8+

## Preserved from v3.7

- Split-script layout.
- 4000-line implementation guard.
- Static smoke validation of current versioned script parts.

## Added in v3.8

- Branch relationship helper functions are implemented in the core history module rather than only in UI code.
- Pester tests cover branch relationship command plans, count parsing, and summary formatting.
