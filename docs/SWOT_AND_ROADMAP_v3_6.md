# Git Glide GUI v3.6.1 - SWOT and Roadmap

## Strengths

- Lightweight Windows deployment.
- Strong Git workflow coverage for daily development.
- Growing modular architecture.
- Command previews and safety prompts.
- Good beginner onboarding and learning guidance.
- Recovery tab now handles conflict state, staging resolved files, and continue/abort guidance.

## Weaknesses

- Still PowerShell/WinForms and Windows-only.
- True visual graph is still early.
- Conflict resolution is guided, not yet a full three-way visual merge tool.
- Monolithic UI script remains large despite service extraction.

## Opportunities

- Build a lightweight open-source Git teaching and safety tool.
- Expand graph/history into a differentiating visual workflow.
- Add GitHub/GitLab integration later.
- Use learning guidance and safe previews to serve beginners and AI-assisted coding workflows.

## Threats

- Mature Git GUIs already provide visual graph and merge tools.
- PowerShell/WinForms can be fragile across environments.
- Maintaining compatibility with old Pester/Windows environments adds complexity.

## Recommended next iteration

- Improve true visual graph rendering.
- Add conflict file badges and resolved-file verification.
- Add reflog/recovery browser planning.
