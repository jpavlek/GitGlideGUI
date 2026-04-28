# Git Glide GUI v3.9.0 Architecture

## Theme

Guided conflict resolution with minimal architectural risk.

v3.9.0 adds a conflict assistant as a UI-free core module and integrates it into the existing recovery workflow. The design keeps Git command planning testable and separate from WinForms rendering.

## New module

```text
modules/GitGlideGUI.Core/GitConflictAssistant.psm1
```

## Module responsibilities

`GitConflictAssistant.psm1` owns:

- unmerged-file command plan
- unmerged-file output parsing
- conflict marker scanning for text
- conflict marker scanning for files
- conflict marker summary formatting
- path safety checks for Git file arguments
- ours command plan
- theirs command plan
- stage-resolved command plan
- stage-resolved safety decision
- operation-aware continue command plans
- operation-aware abort command plans
- conflict resolution guidance text

## GUI responsibilities

The GUI owns:

- rendering the Conflict Resolution Assistant controls
- refreshing the unmerged-file list
- responding to file selection
- showing selected-file scan summaries
- asking for confirmation
- executing approved command plans
- refreshing repository status after command execution

## Safety boundary

The core module creates command plans and safety decisions.

The GUI decides when to execute them.

This avoids putting direct repository mutation inside the module and keeps the behavior testable.

## Command-plan pattern

The conflict assistant follows the existing project direction:

```text
User intention
  -> command plan
    -> visible command preview
      -> confirmation when needed
        -> execution
          -> status refresh
```

This preserves Git transparency and avoids hidden magic.

## v3.9.0 integration points

Expected import location:

```text
scripts/windows/GitGlideGUI.part01-bootstrap-config.ps1
```

Expected UI/helper integration area:

```text
scripts/windows/GitGlideGUI.part04-recovery-push-stash-tags.ps1
scripts/windows/GitGlideGUI.part05-ui.ps1
```

Expected tests:

```text
tests/GitConflictAssistant.Tests.ps1
```

Expected documentation:

```text
docs/CONFLICT_RESOLUTION_ASSISTANT_v3_9.md
docs/RELEASE_NOTES_v3_9_0.md
```

## Architecture risks

### UI crowding

The recovery area now contains more concepts:

- Repository State Doctor
- conflict marker scanner
- unmerged file guidance
- operation continue/abort
- conflict assistant

This increases pressure on the fixed WinForms layout.

### Marker-based smoke tests

Static smoke checks are useful but partly brittle because they check for expected strings and function names.

Future direction:

- keep static smoke checks
- add more Pester tests for command-plan helpers
- add lightweight GUI behavioral smoke tests later

### Large UI parts

`part05-ui.ps1 remains` a high-pressure file. v3.10 should extract layout/panel helpers rather than continuing to add more direct UI construction code.

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

