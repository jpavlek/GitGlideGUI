# Roadmap Review v3.7.0

v3.7.0 deliberately combines one user-facing improvement theme with one architecture theme.

## User-facing theme

The Recovery tab becomes more useful through Repository State Doctor and conflict marker scanning. This directly supports safe recovery from detached HEAD, diverged branches, active merges, unresolved conflicts, and parser failures caused by conflict markers.

## Architecture theme

The monolithic GUI script is split into a small entrypoint and six ordered implementation files. This is not the final architecture, but it spreads risk and makes later extraction safer.

## Why not extract everything now?

A full rewrite into separate UI classes/modules would be higher risk. The v3.7.0 split keeps runtime ordering almost identical to v3.6.13/v3.7 behavior while creating practical boundaries for future versions.

## Next version recommendation

v3.7.1 should extract the pure Repository State Doctor decision logic into `modules/GitGlideGUI.Core/GitRepositoryStateDoctor.psm1` and add focused Pester tests. That will reduce `$script:` coupling without changing UI layout at the same time.
