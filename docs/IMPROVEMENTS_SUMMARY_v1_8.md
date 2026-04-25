# GitFlowGUI v1.8 - Appearance Splitter Startup Fix

## Problem fixed

`GitFlowGUI-Improved9.ps1` could crash during startup with:

```text
Exception setting "Panel2MinSize": "SplitterDistance must be between Panel1MinSize and Width - Panel2MinSize."
```

The crash happened in the new Appearance tab because the script assigned:

```powershell
$appearanceMainSplit.Panel1MinSize = 220
$appearanceMainSplit.Panel2MinSize = 260
```

while WinForms was still constructing the control at a small temporary width. WinForms validates splitter constraints immediately, before the control has been docked and resized into its final layout.

## Changes in v1.8

- Reduced construction-time Appearance splitter minimums to safe values.
- Kept the Appearance splitter visible and discoverable.
- Persisted the Appearance tab splitter position as `AppearanceSplitDistance` in `GitFlowGUI-Config.json`.
- Restored the saved Appearance splitter distance after the form is shown, using the existing safe splitter-distance clamp.
- Updated the Appearance help text to explain that the color-list/editor splitter can be dragged.
- Bumped startup log text to v1.8.

## Why this is safer

The GUI no longer assumes the control has its final size during construction. This avoids startup crashes on different DPI settings, screen sizes, or parent layout timing.

## Recommended test

1. Start the GUI.
2. Open **Common actions → Appearance**.
3. Drag the vertical splitter between the color list and color editor.
4. Close and reopen the GUI.
5. Confirm the position is remembered.
6. Change one color, save it, close/reopen, and confirm the color persists.
