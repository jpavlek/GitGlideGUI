# Git Glide GUI v3.6.4 Roadmap Review

v3.6.4 moves the roadmap forward mainly in History / Graph and release discipline.

## Progress update

| Area | v3.6.1 | v3.6.4 | Change |
|---|---:|---:|---:|
| Foundation stability and startup safety | 90% | 91% | +1 pp |
| Automated quality checks | 79% | 82% | +3 pp |
| History / graph | 42% | 50% | +8 pp |
| Conflict recovery | 59% | 60% | +1 pp |
| Repository/release discipline | 70% | 76% | +6 pp |

Approximate original-roadmap completion: **63%**.

## Why the increase is modest but useful

This is not a full visual graph engine yet. It is a safer, clearer parsed history table with explicit ref categories. That is a necessary step before implementing a real lane renderer or graph panel.

## Next best iteration

v3.6.4 should focus on file-level conflict verification because it directly improves safety and average-user confidence during one of Git's most stressful workflows.
