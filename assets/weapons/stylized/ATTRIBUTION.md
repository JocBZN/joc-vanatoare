# Legacy stylized weapon sources and retained audio

Only free assets are used. No commercial pack has been purchased.

The thirteen model assets recorded below are **legacy, unused by the current weapon wrappers**. They are retained for provenance and possible recovery. Current weapon and recovery-knife model credits, license, extraction and gameplay mappings are in [OBUR weapon attribution](../obur/ATTRIBUTION.md). The table's reload and scope notes describe the earlier integration; the current Patrol SCAR (`old_rifle`) uses iron sights.

| Weapon | Original author / source | License | Imported and authored work |
| --- | --- | --- | --- |
| Rusty pistol | Quaternius, [Animated Pistol](https://poly.pizza/m/gmR2e0hWSF), Animated Guns Pack | CC0 1.0 | Source skinned rig with `Fire`/`Reload`/`Slide` actions; reload clip is played in-game, time-scaled to the weapon's actual reload duration |
| Old rifle | Quaternius, [Assault Rifle](https://poly.pizza/m/Bgvuu4CUMV), Ultimate Guns Pack | CC0 1.0 | Static mesh; wrapped with a corrective rotation/scale/position so it sits correctly in the existing viewmodel and third-person mount, and a `Muzzle` marker was added for muzzle flash/tracer origin |
| Double barrel | Quaternius, [Shotgun Sawed Off](https://poly.pizza/m/29FXKu7G91), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Scrap Blaster | Quaternius, [Shotgun Short Stock](https://poly.pizza/m/MHv3uOV6ja), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Beehive | Quaternius, [Submachine Gun](https://poly.pizza/m/7ehatxr7FY), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Sniper rifle | Quaternius, [Sniper Rifle](https://poly.pizza/m/ASOMZIErq3), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above; the 4x scope is the existing generic scope-overlay reticle and FOV zoom, shared with Old rifle |
| Thunder Tube | Quaternius, [Lightning Gun](https://poly.pizza/m/Nl8qWErOw2), Sci-Fi Gun Pack | CC0 1.0 | Same wrapper treatment as above |
| Revolver | Quaternius, [Revolver](https://poly.pizza/m/9C26wSpMS0), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Assault rifle | Quaternius, [Assault Rifle](https://poly.pizza/m/fpLucho45C), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Railgun | Quaternius, [Sniper Rifle](https://poly.pizza/m/Nq5dnqeh0k), Sci-Fi Gun Pack | CC0 1.0 | Same wrapper treatment as above |
| Ray gun | Quaternius, [Ray Gun](https://poly.pizza/m/DIcib0mihf), Sci-Fi Gun Pack | CC0 1.0 | Same wrapper treatment as above |
| Chain SMG | Quaternius, [Submachine Gun](https://poly.pizza/m/nsP3JukU73), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |
| Nova | Quaternius, [Shotgun](https://poly.pizza/m/8Z4HaN1NyS), Ultimate Guns Pack | CC0 1.0 | Same wrapper treatment as above |

These legacy models were downloaded from poly.pizza's public static CDN (`static.poly.pizza/*.glb`). The individual pages list CC-BY 3.0, while Quaternius publishes the referenced packs as CC0 — see https://quaternius.com. Their author/source credits are retained here; this legacy notice does not describe the license of the newer OBUR assets.

In the earlier integration, the full sourced GLBs were instanced in `actors/equipment/<id>.tscn` and retained their baked textures. The current wrappers use the OBUR models instead.

Only the legacy Rusty pistol contains baked animations. Current OBUR models have no clips and use the game's procedural reload motion (`actors/hunter/first_person_weapon.gd`).

## Gunshot audio sources

These audio sources **remain in use** after the model replacement. Weapon names below refer to the existing gameplay entries; their IDs and audio paths are unchanged.

| Weapon | Source recording | License |
| --- | --- | --- |
| Rusty pistol | Vincent Sevedge, [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) — CZ-52 pistol | CC-BY 3.0, credit: Vincent Sevedge |
| Old rifle | Vincent Sevedge, [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) — SKS rifle | CC-BY 3.0, credit: Vincent Sevedge |
| Sniper rifle | Vincent Sevedge, [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) — Mosin Nagant rifle | CC-BY 3.0, credit: Vincent Sevedge |
| Double barrel | Vincent Sevedge, [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) — shotgun | CC-BY 3.0, credit: Vincent Sevedge |
| Beehive, Scrap Blaster, Revolver, Assault rifle, Chain SMG, Nova | [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) (PPSh, Mossberg, Smith & Wesson 642, AK-47, Carl Gustav M45, Nova respectively) | CC0, per the submission page | 
| Railgun, Ray gun | Synthesized for this project (`work/sound_sources/synth_scifi_sounds.py`), no real recording used | n/a |

All real recordings above are longer raw takes (multiple shots and/or reverb tails); each was trimmed to the single loudest transient, downmixed to mono, resampled to 44100Hz and normalized (`work/sound_sources/extract_shots.py`, `extract_lib_shots.py`) before being placed in `assets/audio/`.

Legacy pack license: https://creativecommons.org/publicdomain/zero/1.0/ (legacy models only); individual gunshot sources are credited above. Current OBUR models use [CC BY 4.0](../obur/ATTRIBUTION.md).
