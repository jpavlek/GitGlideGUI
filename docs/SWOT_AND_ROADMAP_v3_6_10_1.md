# SWOT and Roadmap v3.6.10.1

## Strengths

- Preserves developer control while reducing accidental Git Flow bypasses.
- Keeps Git as the final source of truth instead of over-blocking valid operations.
- Improves test reliability for merge/publish workflow guidance.

## Weaknesses

- Protected-branch checks are advisory and local only.
- The tool does not yet enforce GitHub branch protection rules.

## Opportunities

- Add configurable protected branch names.
- Add a rescue workflow for commits accidentally made on `main`.
- Integrate GitHub branch protection guidance and pull-request workflow checks.

## Threats

- Too many warnings can create warning fatigue.
- Too few warnings can let users unintentionally bypass the intended workflow.

## Next priority

Add a workflow state panel and rescue actions for accidental direct commits on `main` or `develop`.
