# OBUR weapon pack — current models

**Weapon Pack of 10/100 Part 1** by **[OBUR Games](https://sketchfab.com/OburGames)**,
licensed **[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)**.

- [Original Sketchfab model](https://sketchfab.com/3d-models/weapon-pack-of-10100-part-1-79f1c9b1d9d146a6adc7837b01bc22e3)
- Author, title, source URL and license are embedded in the supplied GLB metadata and retained in `source_receipt.json`.
- Original supplied file: `source/weapon_pack_of_10100_part_1.glb`, SHA-256 `cc515bc1b940ae0106b3a1b817f5b102d0cb0a226cbb4190c6f3652ce641c4cc`. Its folder has `.gdignore`; the full display scene is retained for provenance rather than imported at runtime.

No pack was purchased. Attribution to OBUR Games does not imply endorsement of this game or its modifications.

## Changes and extraction

`tools/asset_pipeline/build_obur_weapons.py` extracts eleven individual GLBs from the source groups, removes their display-layout transforms and preserves the source mesh geometry and palette. Gameplay wrappers correct the axes, grip alignment, scale and muzzle position. Some wrappers apply local material tints for the game's fictional variants. These are project modifications, not alternative models supplied by OBUR Games.

The source contains no animation clips. In-game reload motion is procedural. Optics, muzzle effects, recoil, energy effects and the retained gameplay statistics are authored by the project rather than supplied animation or simulation from this pack.

## Runtime mapping

The thirteen stable gameplay IDs retain their statistics and progression. They use eight firearm groups; visual names reflect the actual source silhouettes.

| Gameplay ID | Extracted source group / file | Presentation in game |
| --- | --- | --- |
| `rusty_pistol` | Baretta93R / `baretta_93r.glb` | Baretta 93R starter pistol |
| `old_rifle` | FN_SCAR_L / `fn_scar_l.glb` | Patrol SCAR, semiautomatic with iron sights |
| `double_barrel` | Maverick88 / `maverick_88.glb` | Compact Maverick variant; single-barrel source model |
| `scrap_blaster` | Maverick88 / `maverick_88.glb` | Fictional Scrap Blaster variant |
| `beehive` | UZI / `uzi.glb` | UZI Beehive automatic variant |
| `sniper_rifle` | G36_K / `g36_k.glb` | G36 Marksman variant with the game's scope |
| `thunder_tube` | M72LAW / `m72_law.glb` | Fictional Thunder Tube coil variant, preserving the existing firing mechanic |
| `revolver` | Tarran_Tactical / `tarran_tactical.glb` | Tarran Tactical pistol; the stable ID is historical |
| `ak_rifle` | FN_SCAR_L / `fn_scar_l.glb` | Automatic SCAR-L |
| `railgun` | G36_K / `g36_k.glb` | Fictional G36 energy/rail variant |
| `raygun` | Baretta93R / `baretta_93r.glb` | Fictional Baretta-shaped laser pistol variant |
| `chain_smg` | MG42 / `mg42.glb` | MG42 automatic weapon |
| `nova_shotgun` | Maverick88 / `maverick_88.glb` | Maverick 88 shotgun |

The pack does not supply a revolver, double-barrel shotgun, dedicated sniper rifle or science-fiction weapon. Those old IDs and fictional mechanics are kept for gameplay compatibility; the new RO/EN names and descriptions identify their current models and variants honestly.

`gerber_lmf.glb` supplies the Gerber recovery knife for the local manual-harvest presentation, without an additional purchase. The source `m24_grenade.glb` and `rocket.glb` are extracted for completeness and are not added as usable weapons. The source group `Cylinder.016` is a rocket projectile, **not a suppressor**.

Gunshot audio remains from the existing project sources; OBUR's GLB provides no audio. See the retained [gunshot credits](../stylized/ATTRIBUTION.md#gunshot-audio-sources). The previous weapon meshes are retained as [legacy assets](../stylized/ATTRIBUTION.md).
