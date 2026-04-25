# Git Glide GUI v3.6.10 SWOT and Roadmap

## Strengths

- Safer branch switching without unnecessary blocking.
- Clearer developer control: warn first, then let the user decide.
- More faithful to Git's actual behavior.

## Weaknesses

- The GUI does not yet predict exactly whether dirty files overlap with the target branch.
- Auto-stash is not yet integrated into this specific switch workflow.

## Opportunities

- Add preflight branch-diff analysis.
- Add one-click stash-and-switch with explicit recovery guidance.
- Add branch cleanup after merge/publish.

## Threats

- Too many confirmations can slow users down.
- Too few confirmations can surprise beginners.

## Recommendation

Keep the new switch-anyway choice, but add smarter preflight details in the next iteration.
