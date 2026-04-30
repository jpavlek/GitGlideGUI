## Planned layout refinement: nested panel-host behavior

The current Collapsible Panel Host supports both outer and inner workspace panels.

Current nested structure:

```text
topWorkflow       -> MainWorkSplit Panel1
repositoryStatus  -> HeaderTopAreaSplit Panel1, inside topWorkflow
changedFiles      -> ContentSplit Panel1
diffAndOutput     -> ContentSplit Panel2
diffPreview       -> RightSplit Panel1, inside diffAndOutput
liveOutput        -> RightSplit Panel2, inside diffAndOutput

This is acceptable for v3.10.2, but future versions should make nested behavior explicit and deterministic.

Required improvements:

Document parent/child panel relationships in the Layout State Model.
Add tests for nested collapse/restore behavior.
Ensure Restore all panels restores outer containers before inner containers.
Ensure collapsed parent panels clearly imply hidden child panels.
Consider adding parent/child metadata to the canonical panel registry.

Recommended target:

v3.10.3: document and test nested panel-host behavior.
v3.10.4: use parent/child metadata for deterministic restore order.