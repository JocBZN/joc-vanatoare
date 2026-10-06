# Arme OBUR — integrare și reproducere

Actualizat: 6 octombrie 2026. Implementarea este integrată; rerularea finală a testelor și capturilor este în curs.

Pachetul GLB furnizat de utilizator, **Weapon Pack of 10/100 Part 1** de **OBUR Games**, are
2.241.280 bytes și metadate explicite pentru autor, sursă și **CC BY 4.0**. Originalul este
păstrat în `assets/weapons/obur/source/`, cu `.gdignore`. Licența, linkurile și modificările
sunt descrise în [atribuirea OBUR](../assets/weapons/obur/ATTRIBUTION.md). Meniul jocului afișează
linkuri către pachet, autor și licență, plus „Modele adaptate” / „Adapted models”, inclusiv în export.

## Modele și compatibilitate

Cele treisprezece ID-uri, statistici, prețuri, upgrade-uri, sloturi și fișiere audio sunt
păstrate. Opt grupuri de arme înlocuiesc modelele vechi; denumirile RO/EN descriu noile
siluete. Variantele Scrap/Thunder/Rail/Laser rămân mecanici fictive explicite.

| ID păstrat | Model sursă / variantă |
| --- | --- |
| `rusty_pistol` | Baretta 93R |
| `old_rifle` | SCAR-L de patrulare, semiautomată, cu cătare mecanică |
| `double_barrel` | Maverick 88 compact, sursă cu o singură țeavă |
| `scrap_blaster` | Maverick 88, variantă Scrap Blaster |
| `beehive` | UZI Beehive |
| `sniper_rifle` | G36 K Marksman, cu luneta existentă din joc |
| `thunder_tube` | M72 LAW, variantă electromagnetică fictivă |
| `revolver` | Pistol Tarran Tactical |
| `ak_rifle` | SCAR-L automată |
| `railgun` | G36 K, variantă de energie fictivă |
| `raygun` | Baretta 93R, variantă laser fictivă |
| `chain_smg` | MG42 |
| `nova_shotgun` | Maverick 88 |

Pachetul nu conține revolver, shotgun cu două țevi, armă dedicată de lunetist sau model
science-fiction. ID-urile istorice păstrează compatibilitatea progresului; descrierile nu
pretind asemenea geometrie. Gerber LMF înlocuiește cuțitul procedural de recoltare;
mâinile originale și mișcarea unică de 225 ms după ACK sunt păstrate. Grenada și racheta
sunt extrase, fără adăugarea unor arme utilizabile; `Cylinder.016` este proiectil, nu amortizor.

## Geometrie, cătare și animație

Builder-ul extrage unsprezece GLB-uri, elimină transformările de prezentare și păstrează
geometria, UV-urile, paleta și materialele metal/plastic. Wrapper-ele au bază cu determinant
pozitiv: +X brut devine −Z în Godot, +Z brut devine +Y; MG42 este nivelată cu 18,013°.
`Muzzle`, `Grip`, `SupportGrip`, `FrontSight` și `RearSight` provin din măsurători și
`tools/asset_pipeline/obur_weapon_fit.json`, împreună cu scările și nuanțările discrete.

Mâinile urmează marker-ele de prindere. Nu se suprapun cătări din box-uri peste cele
native: se adaugă numai puncte emissive mici. ADS aliniază înălțimile diferite ale cătării
față/spate prin pitch; offset-urile native sunt 1,5 mm, iar distanța dintre punctele MG42
este calibrată. Poziția hip a armelor lungi ține cont de limita posterioară a modelului,
pentru a evita tăierea la near plane. Lumina locală first person are energie 0,14.

Nuanțările creează copii locale de material și nu modifică resursele partajate între
arme. Pachetul nu are animații: toate cele treisprezece folosesc fallback-ul procedural
existent de coborâre/revenire la reload, cu duratele proprii. Sunetele păstrează
[atribuirile anterioare](../assets/weapons/stylized/ATTRIBUTION.md#gunshot-audio-sources).

## Pipeline și validare

Builder-ul necesită numai biblioteca standard Python. Comenzile reconstruiesc, respectiv
verifică fără scriere, cele 11 GLB-uri, 13 wrapper-e și receipt-ul SHA-256:

```powershell
python tools/asset_pipeline/build_obur_weapons.py
python tools/asset_pipeline/build_obur_weapons.py --check
```

`tests/preview_weapons.gd` produce 40 imagini: creditul din meniu și hip/ADS/reload pentru
toate cele 13 arme. Are 26 verificări relevante ale geometriei sursă la muzzle și alinierii
cătării cu raza camerei sau vizibilității reticulului de lunetă. Folosește viewport-ul
logic `get_visible_rect()`, evitând comparația cu dimensiunea fizică a ferestrei.

În testarea intermediară au fost depistate și corectate baza transpusă la serializarea
`Transform3D` și 11 false eșecuri ADS din compararea viewport-urilor.
Validare finală locală Godot 4.7.2, după toate ajustările:

- Nouă suite headless: **532 checks, 0 failures**, raport
  `tests/results/headless_20261006_103500_f7094f`.
- ENet Forest și Swamp, host + trei clienți + refuzarea celui de-al cincilea:
  **208 checks, 0 failures** pe fiecare hartă. Rapoarte
  `tests/results/run_20261006_103650_911182` și `run_20261006_103948_c2a3e0`.
- Forward+ real: toate cele 40 de capturi și **26 verificări, 0 eșecuri**;
  `WEAPON_PREVIEW_DONE qa_failures=0`, exit 0. Verificate hip, ADS, reload și creditul;
  `work/obur-game-preview-final.log` din conversație. Capturi livrate:
  `outputs/arma_SCAR_L.png` și `arma_SCAR_L_ochire.png`.
- Preview-ul recoltei cu Gerber produce toate cele trei capturi, exit 0, fără erori:
  `outputs/jupuire_interactiune.png`, `jupuire_mini_joc.png`, `jupuire_calitate.png`.
- Builder `--check`, traduceri RO/EN și whitespace curate. Jocul normal a fost redeschis,
  cu pornire fără erori în `work/obur-live-game.log` din conversație.

Totalul acestui lot: **974 verificări, 0 eșecuri** (532 + 208 + 208 + 26).
Validarea anterioară a apei/terenului rămâne documentată separat. Nu s-a făcut commit/push.
