# Git Glide GUI v3.9.1 Conflict Resolution Assistant

## Status

The Conflict Resolution Assistant was introduced in v3.9.0 and remains part of v3.9.1.

v3.9.1 does not substantially change conflict resolution behavior. The main v3.9.1 focus is branch cleanup and remote branch hygiene.

## Existing capability retained

The assistant supports:

- listing unresolved conflict files
- scanning selected files for conflict markers
- blocking stage-resolved while markers remain
- previewing ours/theirs command plans
- previewing stage-resolved command plans
- operation-aware continue and abort command plans

## Safety model

Conflict resolution remains guided, not automatic.

Git Glide GUI does not attempt to automatically resolve conflicts, rewrite files with AI, or silently stage files.

## Relationship to v3.9.1

Branch cleanup and conflict resolution are connected workflows:

```text
merge or release work
  -> possible conflict recovery
    -> quality checks
      -> merge/push/tag
        -> branch cleanup
```

v3.9.1 completes the post-integration cleanup side of this workflow.

## Related documents

```text
docs/CONFLICT_RESOLUTION_ASSISTANT_v3_9_0.md
docs/BRANCH_CLEANUP_ASSISTANT_v3_9_1.md
docs/RELEASE_NOTES_v3_9_1.md
```
