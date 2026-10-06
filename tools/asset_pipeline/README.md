# Free asset pipelines

## OBUR weapon pack

The supplied **Weapon Pack of 10/100 Part 1** by **OBUR Games** is **CC BY 4.0**;
the embedded author/license/source metadata and original 2,241,280-byte GLB are retained
in `assets/weapons/obur/source/` (`.gdignore`). See [OBUR attribution](../../assets/weapons/obur/ATTRIBUTION.md)
and [runtime integration](../../docs/weapons_obur.md). Source metadata is preserved in the SHA-256 receipt.

Requires Python 3's standard library only. Paths resolve from the repository root;
the scripts can be invoked from any working directory by their actual path.

```powershell
python tools/asset_pipeline/build_obur_weapons.py
python tools/asset_pipeline/build_obur_weapons.py --check
```

The first command rebuilds **11 extracted GLBs, 13 equipment wrappers and the receipt**.
The second compares every output byte-for-byte without writing. Unreferenced buffers
and images are pruned while geometry, UVs, palette and source materials are preserved.
`obur_weapon_fit.json` defines measured muzzle/grip/support/sight markers, final lengths,
MG42 leveling and optional local tints. A positive-determinant basis maps raw +X forward
to Godot −Z and raw +Z up to +Y; serialized `Transform3D` basis rows require care.

The retained IDs, statistics and audio are unchanged. Eight firearm groups serve the
thirteen gameplay entries; Gerber LMF serves manual recovery. Grenade and rocket outputs
are retained without new playable weapons (`Cylinder.016` is the rocket). No source
animation clips exist; reload and the knife's 225 ms confirmed-cut motion remain procedural.

Import Godot after rebuilding. `tests/preview_weapons.gd` renders the menu credits plus
hip/ADS/reload for every weapon (40 images) and validates muzzle geometry/camera alignment
with 26 checks. Native iron-sight markers receive only tiny emissive dots; camera validation
uses logical viewport dimensions. Use `HUNT_PREVIEW_DIR` to select the output folder.
Rerun headless and visual checks after changing fit data; final results belong in `CONTEXT_PROIECT.md`.

## Water surface textures

The natural-water maps are built from two retained CC0 heightmap frames by zookeeper. They use periodic height derivatives for seamless +Y normals and original cellular foam noise. See [water attribution](../../assets/art/water/ATTRIBUTION.md). Requires Python, NumPy and Pillow; no new runtime dependency.

```powershell
python tools/asset_pipeline/build_water_textures.py
python tools/asset_pipeline/build_water_textures.py --check
```

The second command verifies reproducibility without writing. An optional `--archive path/to/waves5.zip` re-extracts the two source frames after downloading the archive linked in the attribution. Only the three small runtime textures and two source frames are retained in Git.

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
