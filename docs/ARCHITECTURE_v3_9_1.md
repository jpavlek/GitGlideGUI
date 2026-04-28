# Git Glide GUI v3.9.1 Architecture

## Theme

Branch cleanup and remote branch hygiene with minimal architectural risk.

v3.9.1 adds a UI-free branch cleanup module and integrates it into the existing Integrate workflow.

## New module

```text
modules/GitGlideGUI.Core/GitBranchCleanup.psm1
```

## Module responsibilities

`GitBranchCleanup.psm1` owns:

- fetch/prune command planning
- local branch verbose parsing
- remote branch parsing
- merged branch parsing
- protected branch detection
- local branch delete command planning
- remote branch delete command planning
- cleanup candidate classification
- cleanup summary formatting

## GUI responsibilities

The GUI owns:

- rendering the Branch Cleanup Assistant controls
- refreshing branch cleanup state
- asking for confirmation before deletion
- executing approved command plans
- refreshing repository status after cleanup actions

## Safety boundary

The core module creates command plans and safety decisions.

The GUI decides when to execute them.

This keeps Git mutations visible, testable, and confirmation-based.

## Command-plan pattern

The branch cleanup assistant follows the existing project direction:

```text
Inspect branch state
  -> classify cleanup candidates
    -> preview exact command
      -> confirm destructive action
        -> execute selected cleanup
          -> refresh repository state
```

This preserves Git transparency and avoids hidden magic.

## Integration points

Expected import location:

```text
scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1
```

Expected adapter location:

```text
scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1
```

Expected UI location:

```text
scripts/windows/GitGlideGUI.part05-ui.ps1
```

Expected tests:

```text
tests/GitBranchCleanup.Tests.ps1
```

Expected documentation:

```text
docs/BRANCH_CLEANUP_ASSISTANT_v3_9_1.md
docs/RELEASE_NOTES_v3_9_1.md
docs/ROADMAP_REVIEW_v3_9_1.md
docs/SWOT_AND_ROADMAP_v3_9_1.md
docs/ARCHITECTURE_v3_9_1.md
docs/TECHNICAL_DEBT_REDUCTION_PLAN_v3_9_1.md
```

## Architecture risks

### UI crowding

The Integrate tab now includes merge/publish, quality checks, PR helpers, and branch cleanup.

This increases layout pressure.

### Remote deletion risk

Remote branch deletion affects shared repository state, so confirmation and protected-branch blocking must remain strict.

### Marker-based smoke tests

Static smoke checks are useful but partly brittle because they check for expected strings and function names.

Future direction:

- keep static smoke checks
- add more Pester tests for command-plan helpers
- add lightweight GUI behavioral smoke tests later

### Large UI parts

`part05-ui.ps1` remains a high-pressure file. v3.10 should extract layout/panel helpers rather than continuing to add more direct UI construction code.

## Next architecture milestone

v3.10.0 should introduce a layout state model independent of WinForms controls.

Example:

```text
{
  "schemaVersion": 1,
  "activeProfile": "workflow",
  "savePolicy": "ask-on-exit",
  "panels": {
    "changedFiles": {
      "visible": true,
      "collapsed": false,
      "dock": "left",
      "weight": 0.35
    },
    "preview": {
      "visible": true,
      "collapsed": false,
      "dock": "fill",
      "weight": 0.45
    },
    "output": {
      "visible": true,
      "collapsed": false,
      "dock": "bottom",
      "height": 220
    }
  }
}
```

## Long-term layout direction

Git Glide GUI should evolve toward:

- reusable panel hosts
- collapsible panels
- stackable tab groups
- simulated docking through SplitContainers and TabControls
- explicit save/discard layout controls
- named layout profiles
- mode-specific layouts for Simple, Workflow, Expert, Recovery, Metrics, and Release workflows
