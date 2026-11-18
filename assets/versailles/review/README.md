# Versailles asset review project

This isolated Godot 4.7.2 Compatibility-renderer project imports and compares shortlisted environment assets. It lives outside the main game project, so its review candidates do not enter the game's resource export. Poly Haven and Quaternius samples are loaded from `../source`; Kenney sample models are copied into `source_samples/kenney` from the official CC0 pack.

Open `assets/versailles` as a Godot project or run:

```powershell
Godot --path assets/versailles --editor --import
Godot --path assets/versailles --write-movie art_source/output/versailles_asset_review.png --fixed-fps 30 --quit-after 1
```

The model cells are normalized to a common display height. Printed `ASSET_METRIC` lines report source bounds, mesh/surface counts, triangle counts, and source texture sizes. Candidate status and source/license decisions are recorded in `docs/ASSET_LICENSES.md`.

The refreshed gallery capture is `assets/versailles/review/previews/versailles_asset_review.png`; it grounds each sample by its measured lower bound so feet and bases remain visible above the stage.
