# Natural water textures

The two normal maps derive from **Seamless looping waves heightmaps** by **zookeeper**:

- Source: https://opengameart.org/content/seamless-looping-waves-heightmaps
- Download: https://opengameart.org/sites/default/files/waves5.zip
- License: **CC0 1.0 Universal**, https://creativecommons.org/publicdomain/zero/1.0/
- Retained source frames: `source/waves5_000.png`, `source/waves5_067.png` (512 × 512).

`water_normal.png` and `water_detail_normal.png` are normalized tangent-space +Y maps derived from periodic centered height differences, scaled for calm inland water. Two independently scrolling layers preserve small wave detail without baking photographic reflections or color into the surface. `water_foam.png` is original deterministic periodic cellular noise generated for this project.

Rebuild with `python tools/asset_pipeline/build_water_textures.py`; use `--check` to verify exact output hashes without writing. The source frames are retained; the 14 MB animation archive is not shipped. `source_receipt.json` records provenance and SHA-256 hashes.

Technical references (reference material, not redistributed source assets):

- NVIDIA GPU Gems, Mark Finch, [Effective Water Simulation from Physical Models](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models): low-amplitude geometric waves and independent finer normal waves.
- Godot 4.7 [depth reconstruction](https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html) and [screen reading](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html).
