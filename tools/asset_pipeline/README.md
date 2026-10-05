# Free stylized animal asset pipeline

Runtime files are in `assets/animals/stylized/`; current authors, licenses and original versus project-authored animation credits are in [ATTRIBUTION.md](../../assets/animals/stylized/ATTRIBUTION.md). Source archives, Blender QA files and temporary builds stay in ignored `work/animal_sources/`, which Godot skips.

## Deer and wolf

Quaternius creator listings and verified source/runtime SHA256 hashes are recorded in [deer_wolf_sources.json](../../assets/animals/stylized/deer_wolf_sources.json). Download the source GLBs to `work/animal_sources/deer_quaternius_cc0.glb` and `wolf_quaternius_cc0.glb`. No account or purchase is required.

Requires Python 3 and NumPy. Paths resolve from the repository root. The tool preserves source geometry, skin weights and keyframes; it normalizes feet and facing, maps state names and removes duplicate FBX action names. Changed source hashes are rejected.

```powershell
python tools/asset_pipeline/normalize_deer_wolf.py --check
python tools/asset_pipeline/normalize_deer_wolf.py
```

The first command verifies reproducibility without writing. The second intentionally rebuilds the assets and receipt. Optional `--source-dir` and `--output-dir` accept relative or absolute paths. GLB heights are 1.3 m and 1 m; Godot wrappers set final game heights to 1.75 m and 1.35 m without changing gameplay definitions.

## Frog, snake and turtle

Requires Blender 4.5 or compatible, Python 3 and PowerShell. Source licenses, URLs and SHA256 hashes are in [swamp_sources_receipt.json](reports/swamp_sources_receipt.json). The downloader verifies existing/downloaded sources before safe archive extraction. Source rig animations are preserved; missing game states are supplemented as described in [swamp_conversion_report.json](reports/swamp_conversion_report.json).

```powershell
./tools/asset_pipeline/fetch_swamp_sources.ps1
blender --background --python tools/asset_pipeline/convert_swamp_models.py
python tools/asset_pipeline/validate_swamp_glbs.py
```

Use the actual Blender executable path if it is outside PATH. Conversion intentionally rebuilds GLBs and embedded texture exports. The validator checks skins, canonical clips and changing joint channels; it does not replace visual inspection or Godot runtime tests. The checked output is recorded in [swamp_glb_validation.json](reports/swamp_glb_validation.json).

## Bear

The clean CC0 source mesh already exists at `assets/animals/forest/bear.glb`; avoid the broken historical `bear_smooth.glb`. [bear_receipt.json](bear_receipt.json) records its SHA256, the runtime hash and the new 26-bone rig/five project-authored clips. The conversion removes the old atlas and applies painted fur/claws/muzzle/eyes.

```powershell
blender --background --python tools/asset_pipeline/build_bear.py
```

This intentionally rebuilds the runtime GLB and local pose previews under ignored work/. Run the Godot checks below after rebuilding.

## Runtime checks and previews

Import the project after intentional asset rebuilds. Run the full test runner with the actual engine path:

```powershell
./tests/run_headless_tests.ps1 -GodotExecutable 'C:\path\Godot_console.exe'
```

`tests/verify_animated_wildlife.gd` checks all ten species for real skinned rigs, locomotion joint changes and death completion. `tests/verify_art_wildlife.gd` also checks melee windup and replicated attack replay. `tests/preview_animals.gd` renders both fauna galleries; `-- --animal-preview-pose=walk` also supports run/attack. `tests/preview_style.gd` captures lobby, forest and swamp. Visual scripts require normal rendering, for example `--rendering-method gl_compatibility` on the local Intel GPU.
