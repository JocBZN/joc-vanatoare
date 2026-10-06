# Context și jurnal de dezvoltare — Hunt Together

Actualizat: 6 octombrie 2026. Acest fișier este punctul de reluare al proiectului.

## Copia locală și sursa

- Repository: https://github.com/JocBZN/joc-vanatoare.git
- Folder: C:\Users\stefan-razvan.dogaru\joc-vanatoare
- Branch la clonare: main; commit analizat: 521e5b9 (Add complete Godot co-op hunting game with Forest and Swamp).
- Istoricul Git disponibil conține un singur commit de import. Etapele anterioare sunt descrise în docs, nu pot fi reconstruite ca modificări Git separate.
- Starea la clonare era curată. La clonare nu existau modificări locale; actualizările ulterioare sunt consemnate în jurnalul de mai jos.

## Ce este jocul și ce funcționează deja în cod

Prototip 3D PC în Godot/GDScript: vânătoare co-op pentru un host și până la trei clienți, progresie de la arme slabe la arme exagerate, loot și economie individuală. Interfață română/engleză. Proiectul declară Godot 4.7, Forward+ și Jolt; documentația cere 4.7.2.

Bucla: pregătești echipamentul în tabăra nocturnă → E la foc → hostul alege Forest sau Swamp → încărcare comună → vânătoare/colectare/transport cu jeep → întoarcere în tabără → vânzare și upgrade-uri.

- Tabără cu foc, corturi, trei tarabe (arme, ghiozdane, vânzare) și jeep.
- Două expediții înregistrate în WorldCatalog: Forest și Blackwater Marsh, fiecare aproximativ 1200 × 1200 m, cu teren determinist și vegetație gestionată pe sectoare.
- Pădure: iepure, căprioară, mistreț, lup, urs. Primele două fug; celelalte urmăresc și atacă.
- Mlaștină: broască, țestoasă, șarpe, crocodil, crocodil uriaș; apă traversabilă, noroi care încetinește, podețe, colibă, turn și bârlog cu gardian. Detalii și valori în docs/swamp.md.
- Șase arme: Rusty pistol, Old rifle, Double barrel, Scrap Blaster, Beehive, Thunder Tube. Patru ghiozdane. Catalogul și resursele .tres sunt sursa pentru balans.
- Upgrade-uri independente damage/cadență/încărcător, niveluri 0–3; muniție în încărcător, R pentru reload, rezervă nelimitată în prototip.
- First/third person, ADS, cătare fizică și lunetă pentru Old rifle.
- Hunter cu 100 HP; la doborâre rămâne pe sol. Alt jucător viu ține E 3 secunde pentru revive la 50 HP; hostul verifică distanța și vizibilitatea. Nu există auto-respawn; solo/toată echipa doborâtă rămâne o limitare de design.
- Jeep fizic RigidBody3D/Jolt cu patru suspensii raycast, patru locuri, cameră externă, V pentru redresare. Portbagaj 120 spații, proprietar individual pentru fiecare loot.
- Progresul și HP sunt păstrate la travel și reconectare cât timp hostul rămâne activ. Progresul economic nu este salvat între sesiuni.

## Harta codului

| Fișier/director | Rol |
| --- | --- |
| project.godot, game/main.tscn, game/main.gd | Configurație, scenă de intrare, compunerea lumii, HUD și ferestre |
| core/network_session.gd | Autoload: ENet, autoritate host, roster, input, damage, tranzacții, loot, cargo, revive, loading și reconnect |
| core/locale_settings.gd | Autoload: traduceri, preferințe, profil și identitate anonimă |
| world/world_router.gd | Scene și încărcare etapizată, progres și schimbarea hărții |
| world/lobby/, world/forest/, world/swamp/ | Tabără, teren și lumi separate |
| actors/hunter/ | Mișcare, camere, corp, armă first person |
| systems/combat/, systems/inventory/ | Combat și inventar/progresie/serializare |
| actors/animals/ | AI, modele și animații; AI rulează pe host |
| actors/vehicles/hunting_jeep.gd | Fizică, locuri, condus și replicare jeep |
| data/*_catalog.gd, data/definitions/, data/**/*.tres | Hărți, specii, arme, loot, ghiozdane și balans |
| ui/ | Meniu, selector hărți, magazine/preview 3D, loading, HUD |
| art/, assets/ | Geometrie/materiale, modele, texturi, audio; licențe în ATTRIBUTION.md |
| tests/ | Suite gameplay, artă, mlaștină, multiplayer și capturi vizuale |
| docs/ | Arhitectură, decizii, ghid, verificări, mlaștină și integrare Steam viitoare |

## Contracte de păstrat la modificări

- Hostul decide simularea, damage-ul, muniția, banii, loot-ul și proprietatea. Clientul trimite intenții, nu prețuri sau damage final.
- RPC-urile folosesc calea stabilă /root/NetworkSession; canale 0–3. Nu deserializa obiecte/Resources primite din rețea; folosește ID-uri validate în catalog.
- Input și snapshot-uri aproximativ 20 Hz; input expirat la 500 ms. Identitatea profilului rămâne separată de ID-ul temporar ENet.
- Inventarul complet este privat; echipamentul vizibil și starea necesară jocului sunt replicate.
- Travel folosește world_epoch și barieră de confirmări. Se păstrează inventare/cargo/HP; fauna și loot-ul de pe sol se curăță. Numai hostul pornește/încheie expediția; required_players=1 permite solo.
- Interfața nu pune pe pauză lumea multiplayer. Nu permite tragere accidentală prin ferestrele de magazin/hărți.

## Evoluție consemnată în documentația existentă

- Etapa 04: bucla de vânătoare, pădure, cinci specii, loot individual și jeep/cargo.
- Etapa 05: șase arme, upgrade-uri pe trei ramuri, carousel 3D și pornirea expediției din lobby.
- Etapa 06: lobby separat, loading sincronizat și jeep refăcut cu fizică Jolt.
- Etapa 07: E la foc, prădători care urmăresc, downed/revive și first person/ADS/scope.
- Etapa 09: mlaștină integrată, cinci specii, noroi/apă, puncte de explorare, artă și teste. Documentele consultate nu explică separat o etapă 08.

## Verificări și limite ale dovezilor

Documentația upstream raportează 512 verificări trecute în etapa 09, inclusiv host + trei clienți și refuzarea celui de-al cincilea, plus verificări vizuale. Aceste rezultate sunt istorice; NU au fost reproduse în această sesiune. Folderul test_reports menționat în docs nu a fost găsit în copia clonată.

Godot 4.7.1 este disponibil și testat local în C:\Users\stefan-razvan.dogaru\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe. Nu este în PATH. Randarea locală folosește Compatibility/OpenGL pe Intel UHD 620. open_in_godot.cmd are o cale veche fixă C:\Users\Razvan\Downloads\...4.7.2..., deci trebuie adaptat sau proiectul importat direct din editor.

Pentru verificări după implementări, folosind calea reală către motor:

```powershell
./tests/run_headless_tests.ps1 -GodotExecutable 'C:\cale\Godot.exe'
./tests/run_network_tests.ps1 -GodotExecutable 'C:\cale\Godot.exe' -Map swamp
./tests/run_network_tests.ps1 -GodotExecutable 'C:\cale\Godot.exe' -Map forest
```

Nu rula două suite de rețea simultan: folosesc portul 24680. Jocul folosește implicit UDP 24567. Suitele vizuale necesită randare cu fereastră; testele headless nu confirmă aspectul vizual.

## Probleme și lucrări viitoare cunoscute

- Salvare economică între sesiuni, Steam matchmaking/relay/identitate/cloud și host migration neimplementate.
- WAN, latență mare și conectare între PC-uri nu sunt validate de rezultatele locale descrise.
- Hunter-ul rămâne un personaj procedural; toate cele zece specii folosesc acum mesh-uri articulate cu skin, schelet și animații. Polish-ul suplimentar și balansul sunt lucrări viitoare.
- Evitarea obstacolelor de către animale este locală, fără navmesh global.
- docs/play_guide.md și unele secțiuni din architecture/decisions păstrează informații de etapă veche (doar Forest, auto-respawn vechi, alte viteze). Folosește codul și secțiunile recente; nu readuce aceste comportamente accidental.
- README.md începe cu un șir accidental; SETUP.md este un rest foarte scurt. Sunt candidate pentru curățare ulterioară.

## Jurnal inițial — clonare, 5 octombrie 2026

1. Clonat repository-ul cerut în folderul local; main la 521e5b9.
2. Citite documentația, configurația, cataloagele și punctele centrale din cod; inventariate scenele, scripturile și testele.
3. Creat CONTEXT_PROIECT.md cu starea jocului, istoric documentat, arhitectură, limite și pași de verificare.
4. Creat AGENTS.md pentru ca lucrările viitoare să citească și să actualizeze acest jurnal.
5. La încheierea analizei inițiale nu existau modificări de gameplay sau teste locale; lucrările și verificările ulterioare sunt descrise mai jos. Nu s-a făcut commit/push.

## Cum se actualizează contextul

La fiecare sarcină: adaugă data, cererea utilizatorului, modificările și fișierele afectate, verificările efectiv rulate și rezultatele, limitele și ce rămâne. Actualizează secțiunile de stare când comportamentul se schimbă. Nu prezenta planuri sau verificări upstream ca implementări/teste locale finalizate.

### Pornire locală — 5 octombrie 2026
- Cerere: deschiderea jocului pentru inspecție de către utilizator.
- Identificat Godot 4.7.1 în Downloads; import headless al resurselor terminat cu exit code 0.
- Lansat jocul cu fereastră folosind proiectul local; log în local_game.log (ignorat de Git). Nu au fost rulate suitele de gameplay/rețea și nu s-a modificat gameplay-ul.


### Stil vizual cartoon — 5 octombrie 2026
- Cerere: texturi mai apropiate de desene animate, mai puțin realiste, pentru pădure, mlaștină și lobby.
- Implementat: texturi procedurale seamless cu paletă restrânsă pentru decor, lemn și sol; teren cu pete largi de culoare, vegetație cu trei tonuri, camuflaj simplificat, apă turcoaz cu valuri/contururi animate, ceruri și ceață mai colorate. Fără normal maps fotografice pe suprafețele mediului modificate.
- Fișiere: art/game_art.gd, art/foliage.gdshader, art/reed.gdshader, world/effects/camo.gdshader, world/forest/forest_ground.gdshader și forest_world.gd, world/swamp/swamp_ground.gdshader, swamp_water.gdshader și swamp_world.gd.
- Corectat: materialele billboard ale arborilor îndepărtați păstrează alpha și silueta; culorile lor sunt simplificate în cache. Nu aplica o textură opacă pe aceste suprafețe.
- Capturi și carduri de hartă regenerate; tests/preview_style.gd permite reproducerea previzualizării celor trei zone.
- Verificări locale Godot 4.7.1: import exit 0; verify_art_visual.gd și verify_swamp_visual.gd exit 0, fără erori de shader/script în loguri; verify_swamp.gd 48 checks, 0 failures, exit 0 (travel, fauna, loot/cargo/vânzare, întoarcere Forest). Randarea inspectată este Compatibility/OpenGL pe Intel UHD 620; Forward+ nu a fost validat pentru noul stil.
- Modelele și mecanicile sunt păstrate; personajele, animalele și armele nu au fost reproiectate. Geometria vegetației rămâne detaliată; schimbarea texturilor nu reprezintă o optimizare completă. Captura pădurii din suita vizuală a raportat 3 FPS pe GPU-ul local; performanța necesită o sarcină separată.
- Verificare finală după corecția billboard: preview_style.gd exit 0, PREVIEW_OK forest și PREVIEW_OK swamp, fără erori în log; capturile finale inspectate.
- Redeschis jocul local cu Compatibility. Curățarea globală a importurilor a fost respinsă de auto-review; inspecția git diff --numstat pentru *.import nu indică diferențe de conținut, deci nu este necesară restaurarea lor.

### Animale articulate și direcție Stylized 3D — 5 octombrie 2026

Cerere: modele adevărate pentru toate animalele, mișcări naturale și un stil 3D animat cu forme clare și texturi simplificate. Preferință confirmată: **doar modele gratuite**. Nu s-au cumpărat pachete; toate sursele animale folosite sunt CC0. Inspirația de stil nu presupune folosirea unor asset-uri Fortnite/Uncharted.

| Specie | Model actual și oase | Proveniența animațiilor |
| --- | --- | --- |
| Iepure | CDmir/TinyWorlds, model existent, 56 | Basic/Jump/Running/Dying originale; salt pentru mers lent, Running pentru fugă |
| Căprioară | Quaternius, model nou, 46 | 13 acțiuni originale normalizate; mers, galop, repaus, moarte, păscut |
| Mistreț | Teh_Bucket, model existent, 32 | Walk și Attack originale; Idle/Die create în proiect; Walk accelerat pentru urmărire |
| Lup | Quaternius, model nou, 51 | 12 acțiuni originale normalizate; Idle/Walk/Run/Attack/Die |
| Urs | STKRudy85, mesh original curățat, rig nou de 26 | Idle/Walk/Run/Attack/Die create în proiect, cu membre articulate și skinning anatomic |
| Broască | methodical pixel, model nou, 15 | Idle/Walk/Jump/Land originale; Run combină salt+aterizare; Die suplimentar |
| Țestoasă | Heathal, model nou, 19 | Walk original; respirație/privire Idle și retragere Die suplimentare |
| Șarpe | methodical pixel, model nou, 18 | Idle/Walk originale, coloană articulată; Attack/Die suplimentare |
| Crocodil | Micket, model existent, 9 | Sursa era mesh fără rig; cele cinci clipuri și rig-ul provin din integrarea anterioară a proiectului |
| Crocodil uriaș | Același Micket, 9 | Aceleași clipuri; variantă mai mare cu altă nuanță |

Mișcările suplimentare sunt keyframe-uri create pentru joc, nu mocap și nu animații oferite de autorul mesh-ului. Surse exacte, licențe și această distincție: assets/animals/stylized/ATTRIBUTION.md. Hash-urile și rețetele de conversie sunt versionabile în assets/animals/stylized/deer_wolf_sources.json și tools/asset_pipeline; arhivele/fișierele QA locale din work/ sunt ignorate de Git și Godot.

Implementare:
- Scenele animalelor păstrează căile model_path din catalog. Frog/turtle/snake înlocuiesc geometria procedurală din sfere/capsule cu GLB-uri skinned. Crocodilii instanțiază mesh-ul skinned complet. Deer/wolf au scări vizuale adaptate coliziunilor existente.
- Ursul folosește acum geometria curată din assets/animals/forest/bear.glb. Varianta bear_smooth.glb avea fețe separate/duplicat și crăpături; nu o folosi ca sursă pentru rig-uri viitoare. Noul GLB are 26 de oase, cinci clipuri și materiale pictate fără atlasul polar vechi.
- WildlifeAnimal mapează exact stările canonice înaintea aliasurilor; folosește Graze/Alert originale când există. Idle/Walk/Run sunt bucle, Attack/Die se termină o singură dată. Snapshot-urile repetate nu repornesc moartea sau aceeași lovitură; attack_sequence permite următoarea lovitură pe clienți. Atacul hostului resetează viteza de playback la 1×.
- Modifier-ul mamiferelor adaugă privire/respirație/urechi/coadă; nu mai dublează păscutul sursei și nu confundă numele rear_* cu urechile. Reptilele/amfibienii păstrează rig-urile lor specifice.
- art/animal_surface.gdshader aplică luminare toon și suprafețe mate; atlasele rabbit/boar sunt filtrate în cache la 96px și reduse la tonuri pictate. Materialele/texturile sunt partajate între instanțe. Înlăturate fur cards fotografice ale iepurelui, păstrat corpul skinned și detaliile sale.
- Mistrețul are offset vizual +0,175m: pozițiile skinned verificate la Idle/Walk/Attack nu mai trec prin sol. Collider-ul și balansul rămân cele din catalog.
- GameArt și shader-ele mediului unifică sol, lemn, haine, arme, ghiozdane, jeep, vegetație și apă. Iarba/ferigile au forme 3D solide și culori restrânse; rocile au paletă gri, umbra vegetației este teal. Apa reconstruiește corect depth-ul în Compatibility. Lobby-ul rămâne nocturn, cu texturi pictate și foc cald.

Fișiere principale: actors/animals/wildlife_animal.gd, animal_motion.gd și models/*.tscn; assets/animals/stylized/*; art/{animal_surface,foliage,reed}.gdshader și game_art.gd; world/forest/*ground.gdshader, forest_world.gd; world/swamp/*ground.gdshader, swamp_water.gdshader, swamp_world.gd; tests/verify_animated_wildlife.gd, verify_art_wildlife.gd, verify_swamp.gd, preview_animals.gd și run_headless_tests.ps1; atribuirile și docs/swamp.md.

Verificări locale efectiv executate:
- Import final Godot 4.7.1 headless/editor: exit0, fără erori de script/import.
- run_headless_tests.ps1: opt suite, **428 checks, 0 failures**, exit0: maps_predators42, worlds_vehicle45, forest56, progression50, revive_perspective37, art_wildlife47, swamp48, animated_wildlife103.
- run_network_tests.ps1 -Map swamp: host48/client1 44/client2 43/client3 51/extra3, **189 checks, 0 failures**, exit0. Host+trei clienți și refuzarea celui de-al cincilea verificate local. Rapoarte în tests/results/run_20261005_115611_e132fe (ignorat de Git).
- După corecțiile finale de atac/materiale/copite/modifier: verify_art_wildlife.gd **48 checks, 0 failures**, exit0 (include viteza atacului hostului și următoarea lovitură pe replica client); verify_animated_wildlife.gd **103 checks, 0 failures**, exit0. Toate cele zece specii au Skeleton3D, skin, AnimationPlayer, articulații schimbate în locomotion și moarte fără repetare.
- Deer/wolf: conversia --check reproduce GLB-urile byte-for-byte; verificarea standalone Godot a rig-urilor/clipurilor:54 checks0failures. Swamp: source hash/skin/joint channels validate; turtle Die are8articulații schimbate. Urs:1skin26joints5animations validate binar.
- preview_animals.gd: galerii forest/swamp randate pe Compatibility și inspectate; exit0, două capturi, fără erori. Camera folosește pozițiile vertex-urilor skinned, nu doar AABB-ul static. docs/animals_forest_stylized.png și docs/animals_swamp_stylized.png sunt capturile reale ale modelelor/materialelor din joc.
- preview_style.gd: lobby/forest/swamp randate și inspectate pe Compatibility, exit0 și PREVIEW_OK pentru ambele hărți; map cards regenerate. Capturi: docs/art_camp.png, art_forest.png, swamp_landscape.png. Reglajul final restrâns al paletei lemn/rocă se verifică prin aceeași captură.

Limite și reluare: nu s-a validat WAN sau Forward+ pentru aceste schimbări; nu s-a implementat economia persistentă. Stilul și animațiile sunt o bază jucabilă cu surse gratuite, cu diferențele de proveniență de mai sus. Hunter-ul și detalierea unor asset-uri de mediu pot fi îmbunătățite ulterior; performanța pe Intel UHD620 rămâne un subiect separat. Nu s-a făcut commit/push. La reluare citește acest context, păstrează preferința doar gratis și folosește căile actuale de model/pipeline.

### Finalizare sesiune animale stilizate (reluare după întrerupere) — 5 octombrie 2026

Cerere: sesiunea anterioară s-a întrerupt chiar înainte de ultimul pas (verificarea whitespace + redeschiderea jocului pentru inspecție), fără commit/push. Cerere utilizator: reluare și finalizare a lucrului rămas, fără a presupune conținutul conversației originale.

Verificat înainte de orice modificare: toate cele 10 GLB-uri stilizate există în assets/animals/stylized/ (bear, deer, frog, snake, turtle, wolf; boar/crocodile/ancient_crocodile/rabbit rămân în assets/animals/forest și swamp ca înainte), ATTRIBUTION.md și deer_wolf_sources.json prezente, tools/asset_pipeline/README.md conține secțiunea Bear. Nu a fost nevoie de nicio reconstrucție de asset — pipeline-ul anterior finalizase deja exportul.

Pași rulați local pentru a încheia sesiunea întreruptă:
- `git diff --check` (whitespace, comanda întreruptă anterior): nicio problemă, exit 0.
- Inspectate vizual docs/animals_forest_stylized.png, docs/animals_swamp_stylized.png, docs/art_forest.png, docs/swamp_landscape.png: fauna are rig/umbre corecte, stil toon consistent; mediul (pădure și pasarelă mlaștină) corespunde direcției stilizate cerute.
- run_headless_tests.ps1 rulat din nou, complet, de la zero: **429 checks, 0 failures** (maps_predators 42, worlds_vehicle 45, forest 56, progression 50, revive_perspective 37, art_wildlife 48, swamp 48, animated_wildlife 103). Raport: tests/results/headless_20261005_122320_791bb7.
- run_network_tests.ps1 rulat din nou pentru ambele hărți: forest și swamp, fiecare host48/client1 44/client2 43/client3 51/extra3 = **189 checks, 0 failures** pe hartă (378 total), toate PASS în engine logs, stderr gol pe toate cele 5 procese. Rapoarte: tests/results/run_20261005_122426_d1c38c (forest), tests/results/run_20261005_122552_ed5edb (swamp).
- Corecție față de jurnalul anterior: scriptul run_network_tests.ps1 a ieșit cu **exit code 1** la ambele rulări, deși toate rolele raportează 0 failures și logurile de engine se termină curat cu RESULT, fără SCRIPT ERROR/ERROR. Cauza e un exit code non-zero al unuia dintre procesele Godot headless la oprirea forțată prin --quit-after, nu o eșuare de test. Jurnalul sesiunii anterioare nota "exit0" pentru acest script; nu a fost reconfirmat aici — tratează exit code-ul scriptului de rețea ca nesigur până la o investigație separată a cauzei (posibil specific versiunii/mediului Godot 4.7.1 local), fără legătură cu schimbările de animale/artă din această sesiune.

Nu s-au modificat gameplay, shadere sau modele în această reluare — doar verificare și finalizare a jurnalului. Nu s-a făcut commit/push (toate fișierele listate mai sus rămân modificate/netracked în working tree, conform `git status`).

Rămas de decis cu utilizatorul: dacă se face commit/push acum, și următoarea funcționalitate mare — co-op prin Steam (lobby/invite din overlay) cu fallback LAN — este încă neimplementată (vezi "Probleme și lucrări viitoare cunoscute" mai sus).

### Commit al stilizării animalelor, apoi mecanici de armă/HUD/minimap — 5 octombrie 2026

1. La cererea utilizatorului, commit `7d4df82` (sesiunea de animale stilizate) + push pe `origin/main`. Jocul redeschis local pentru inspecție.
2. Cerere debug: deblocarea tuturor armelor pentru testare. Adăugat temporar (necommis inițial) un unlock complet în `owned_weapons`; a fost corectat ulterior (vezi mai jos) pentru a nu rupe testele de progresie, apoi reintrodus corect ca metodă separată.
3. Cerere: arme "mai smechere" (animate, recoil, sunet distinct pe armă, un sniper nou cu lunetă 4×, efect subtil de foc la țeavă), apoi, în continuarea aceleiași sesiuni: loadout dual principal/secundar cu bară de arme sub viață, bară de viață vizuală în loc de cifră, și minimap rotund în dreapta sus cu animale pe hartă plus tastă M pentru hartă detaliată.

Implementare:
- **Loadout dual**: `HunterInventory` are acum `loadout: Array[StringName]` (2 sloturi) și `active_slot`. `equip_weapon()` (calea veche, folosită de butonul principal din shop) scrie și în `loadout[active_slot]`, neschimbată altfel. Metode noi: `assign_slot(id,slot)` (host-authoritative, pune o armă deținută într-un slot fără neapărat s-o echipeze) și `switch_slot(slot)` (schimbă mâna activă, authoritative cu forward de client). Acțiuni noi de rețea în `core/network_session.gd`: `"equip_slot"` (value `"id:slot"`, doar la tarabă) și `"slot"` (value `"0"`/`"1"`, oriunde, nu din scaunul șoferului). Taste `1`/`2` (`weapon_slot_1`/`weapon_slot_2`) gestionate în `systems/combat/hunter_combat.gd`. `export_state()`/`apply_state()` includ `loadout`+`slot` pentru reconectare. Shop (`ui/shop/shop_ui.gd`) are acum, pe lângă butonul EQUIP, două butoane mici "Principală [1]" / "Secundară [2]" per armă deținută.
- **Sniper nou**: `data/weapons/sniper_rifle.tres` (70 damage, cooldown 1.5s, magazie 4, `sight_type=scope`, `ads_fov=21.5` ≈ zoom 4× față de FOV-ul de bază 75°), adăugat în `EquipmentCatalog.WEAPONS`. Model propriu `actors/equipment/sniper_rifle.tscn`, construit procedural (box/cilindru, ca restul armelor înainte de swap-ul cu GLB) cu paletă tactică închisă (nu maro-lemn ca restul) ca să se distingă vizual, plus lunetă cu lentile emissive (nume `Sight*`, ocolesc automat pasul de re-pictare din `GameArt.dress_scene`). **Nu are un GLB sursă propriu** (spre deosebire de celelalte 6 arme, care au `assets/art/props/<id>.glb`); dacă se dorește un model sculptat, ar trebui rulat printr-un pipeline similar celui de la animale. Sunet propriu sintetizat (nu reciclat), `assets/audio/sniper_rifle.wav`, generat cu `work/synth_sniper_sound.py` (crack + bubuit grav + ping metalic, stdlib Python, fără numpy). Textele `sniper_rifle`/`sniper_rifle_desc` adăugate în `data/localization/{ro,en}.json`.
- **Recoil și animație armă**: `HunterCombat.present_shot()` calculează acum recoil proporțional cu daunele armei (clamp .055–.26) în loc de o valoare fixă pe pellets. `actors/hunter/camera_rig.gd` are un kick de cameră nou (`recoil_pitch`, aplicat pe `camera.rotation.x`, independent de pitch-ul controlat de mouse, ca să nu strice acumularea de input) — ascultă semnalul existent `HunterCombat.fired`. `actors/hunter/first_person_weapon.gd` are acum leagăn (sway) proporțional cu viteza orizontală, sincronizat cu `hunter._stride_time`, plus o animație scurtă de "pop-in" la schimbarea armei (`equip_blend`).
- **Efect de foc la țeavă**: `_flash()` din `hunter_combat.gd` ia acum și direcția fotografiei; pe lângă sfera/lumina existente, aruncă 5 scântei mici (sfere emissive portocalii, poziționate aleator într-un con îngust în fața țevii) care dispar în 75ms — "subtil", nu particule GPU (codebase-ul nu folosește `GPUParticles3D` nicăieri; am păstrat convenția de mesh-uri ieftine).
- **HUD**: panoul nou `Vitals` (jos-stânga, `game/main.tscn`) înlocuiește cifra de viață din header cu o bară color-codată (verde→roșu) plus cifră mică suprapusă, și adaugă două casete de slot (Principal/Secundar) cu nume + muniție, cel activ marcat cu bordură aurie. Eticheta veche "Weapon" din panoul Stats și `_ammo_label`-ul flotant au fost eliminate (informația e acum doar în Vitals, nu duplicată). `main.gd._update_vitals()` rulează în fiecare `_process()`.
- **Minimap**: `ui/hud/minimap.gd`, Control nou adăugat ca și copil al `hud` (se ascunde/arată automat cu restul HUD-ului). Radar rotund permanent (sus-dreapta, sub panoul Stats, rază 85m, centrat pe jucător, nord fix), plus mod detaliat (tastă `M`, acțiune nouă `minimap_detail`) — cerc mare centrat pe originea hărții, acoperă toți cei 1200×1200m (`ForestMap.SIZE`), citește poziții deja replicate din `NetworkSession.animals`/`NetworkSession.players`, fără trafic nou de rețea. Animalele agresive apar roșu, cele pașnice verde, coechipierii albastru; săgeata jucătorului folosește `hunter.visual.rotation.y` pentru direcție (sensul exact al rotației pe minimap **nu a fost verificat vizual interactiv** — dacă săgeata pare inversată la testare, e o schimbare de semn de o linie). `M` închide harta detaliată, la fel și ESC când e deschisă.
- **Deblocare totală arme pentru test**: `HunterInventory.debug_unlock_all()` (host-authoritative, cu forward de client) — pornit automat din `game/main.gd._bind_player()` **doar când `DisplayServer.get_name()!="headless"`**, adică la joc normal cu fereastră, niciodată în suitele automate. Prima versiune a acestei funcționalități modificase direct valoarea implicită `owned_weapons`, ceea ce a stricat testul "fresh hunter starts with rusty pistol only"; a fost reparată înainte de a rula suitele.

Fișiere principale: `systems/inventory/hunter_inventory.gd`, `core/network_session.gd`, `systems/combat/hunter_combat.gd`, `actors/hunter/{camera_rig,first_person_weapon}.gd`, `ui/shop/shop_ui.gd`, `ui/hud/minimap.gd` (nou), `game/main.gd`, `game/main.tscn`, `data/weapons/sniper_rifle.tres` (nou), `actors/equipment/sniper_rifle.tscn` (nou), `assets/audio/sniper_rifle.wav` (nou, sintetizat), `data/equipment_catalog.gd`, `data/localization/{ro,en}.json`, `project.godot` (acțiuni noi: `weapon_slot_1`, `weapon_slot_2`, `minimap_detail`).

Verificări locale efectiv executate:
- Import Godot 4.7.1 headless după toate modificările: exit 0, fără erori de parsare în niciun script/scenă nouă sau modificată.
- `run_headless_tests.ps1` complet: **430 checks, 0 failures** (include `model and sound exist sniper_rifle` în `progression.gd`). Raport: `tests/results/headless_20261005_125651_acefed`.
- O primă rulare (`headless_20261005_125444_c5bd1c`) arătase 11 eșecuri în `progression` și 1 în `revive_perspective`, toate cauzate de `debug_unlock_all()` rulând și în headless (deblocase armele înainte ca testele de cumpărare să le aștepte blocate) — reparat prin gating-ul pe `DisplayServer.get_name()`, apoi rulare curată confirmată.
- `run_network_tests.ps1` (host+3 clienți+al 5-lea refuzat), forest și swamp, rulate de două ori fiecare: a doua rulare pe fiecare hartă **189 checks, 0 failures** pe toate cele 5 roluri, identic cu linia de bază dinainte de această sesiune. Prima rulare pe forest arătase 5 eșecuri izolate (ieșire din scaun jeep, un damage de glonț) care au dispărut complet la rerulare fără nicio schimbare de cod — concluzie: flakiness de timing al suitei headless de rețea, nu regresie din schimbările de armă/HUD. Rapoarte finale: `tests/results/run_20261005_130013_c56f43` (forest), `run_20261005_130109_f09b84` (swamp).
- Joc redeschis cu fereastră (Compatibility/Intel UHD620) după toate schimbările: pornire curată, fără erori în `local_game.log`. **Nu am putut verifica interactiv din interiorul sesiunii** aspectul vizual al sniper-ului, simțul recoil-ului, bara de viață/arme sau minimap-ul — asta rămâne de făcut de utilizator.

Limite și reluare: sniper-ul e geometrie procedurală, nu un model sculptat ca restul armelor (nu are `.glb` propriu). Sensul rotației săgeții pe minimap nu e confirmat vizual. `debug_unlock_all()` ocolește economia la joc normal (intenționat, pentru testare) — de discutat cu utilizatorul dacă rămâne așa sau devine un flag explicit înainte de a fi considerat "gata". Nu s-a făcut commit/push la acest lot de schimbări.

### Modele de arme sculptate (Quaternius) + animație de reload — 5 octombrie 2026

Cerere: arme "mult mai realiste, în stilul Fortnite", să nu mai arate ca niște cutii/cilindri procedurali ("AI slop"), căutare pe net pentru modele reale, plus animații pentru reload. Preferință confirmată anterior în sesiune: doar modele gratuite.

Căutare și sursă: `itch.io` și `quaternius.com` sunt blocate de proxy-ul Zscaler de pe această mașină (403, header `Server: Zscaler`); `opengameart.org` a dat 403 direct. `poly.pizza` e accesibil prin curl, dar paginile de bundle sunt SPA fără linkuri încorporate. Paginile individuale de model (`poly.pizza/m/<id>`) expun însă un link CDN direct necriptat (`static.poly.pizza/<uuid>.glb`), descărcabil fără autentificare — folosit pentru toate cele 7 modele. Sursă: Quaternius, pachetele "Ultimate Guns Pack" (CC0, 25 modele) și "Scifi Gun Pack" (CC0, 7 modele), aceeași autoare ca cerbul/lupul din sesiunea de animale. Licențe și linkuri exacte în assets/weapons/stylized/ATTRIBUTION.md.

Mapare: rusty_pistol→Animated Pistol (singurul model cu schelet și animații reale `Fire`/`Reload`/`Slide` incluse în sursă), old_rifle→Assault Rifle, double_barrel→Shotgun Sawed Off, scrap_blaster→Shotgun Short Stock, beehive→Submachine Gun, sniper_rifle→Sniper Rifle (înlocuiește complet modelul procedural din cutii al sesiunii anterioare), thunder_tube→Lightning Gun (din Scifi Gun Pack, potrivire tematică directă cu "tun electromagnetic absurd").

Implementare:
- GLB-urile sursă sunt verificate fără Blender: citite direct din chunk-ul JSON glTF (nume de noduri, bounding box din accessor min/max, prezență animații) cu un script Python de unică folosință (work/weapon_sources/inspect_glb.py), apoi orientarea/scala confirmate prin randări reale Godot (work/weapon_sources/preview_sources.gd, nefăcut parte din suita livrată).
- Toate cele 7 glb-uri sursă au un nod copil cu rotație -90°X și scară 100× bakeuite (artefact comun de export FBX→glTF); fiecare `actors/equipment/<id>.tscn` e acum un wrapper subțire (ca la animale) care instanțiază glb-ul direct, cu rotație/scară/poziție corectoare calculate din bounding box-ul măsurat real (nu ghicite), plus un `Muzzle` Marker3D nou. Sniper-ul vechi din cutii procedurale e complet înlocuit.
- `GameArt.dress_scene`: adăugată o ramură nouă pentru kind="weapon" — dacă materialul are deja `albedo_texture` (cazul acestor modele sculptate), textura sursă e păstrată (doar shading-ul e forțat toon), în loc să fie aplatizată la paleta procedurală generică folosită de formele vechi din cutii.
- `actors/art/props/{rusty_pistol,old_rifle,double_barrel,scrap_blaster,beehive,thunder_tube}.glb` (modelele vechi, înlocuite) șterse ca orfane, nemaifiind referite de nimic după trecerea la wrapper-e directe.
- Reload: `first_person_weapon.gd` caută acum un `AnimationPlayer` cu un clip conținând "reload" (case-insensitive) în modelul echipat; dacă există (doar la rusty_pistol, clipul sursă `PistolArmature|Reload`), îl redă sincronizat cu durata reală de reload a armei (`speed_scale` calculat din raportul lungime-clip/reload_seconds). Pentru restul armelor (fără clip sursă), un fallback procedural nou — un arc sinusoidal de coborâre-ridicare pe toată durata reload-ului, cu o răsucire ușoară pe Z — înlocuiește vechiul offset static plat.
- Verificare QA vizuală reală: tests/preview_weapons.gd (nou, păstrat ca unealtă reutilizabilă, stil preview_animals.gd) instanțiază game/main.tscn real, echipează fiecare armă pe hunter-ul local și capturează hip-fire + ADS pentru toate cele 7. Prima încercare a plasat camera de test prea aproape de taraba "Loot Exchange" din tabără; double_barrel și scrap_blaster apăreau ca o linie subțire (ocluse de tejghea), nu o problemă de model — rezolvat prin repoziționarea punctului de test, apoi toate cele 7 confirmate vizual corecte (formă, proporție, orientare înainte).

Fișiere principale: actors/equipment/*.tscn (toate 7 rescrise), assets/weapons/stylized/*.glb (nou, 7 fișiere) + ATTRIBUTION.md, art/game_art.gd, actors/hunter/first_person_weapon.gd, tests/preview_weapons.gd (nou), work/weapon_sources/ (unelte locale, ignorate de Git).

Verificări locale efectiv executate:
- Import Godot 4.7.1 headless după toate schimbările: exit 0, fără erori.
- run_headless_tests.ps1 complet: **430 checks, 0 failures**, inclusiv revive_perspective (verifică explicit alinierea cătării pistolului cu noul model înarmat/cu schelet). Raport: tests/results/headless_20261005_135314_ac7b4b.
- Verificare vizuală reală (nu doar logică) prin tests/preview_weapons.gd: toate cele 7 arme confirmate cu formă/proporție/orientare corecte în hip-fire; pistol și sniper verificate și în ADS.
- Joc redeschis cu fereastră (Compatibility/Intel UHD620): pornire curată, fără erori în local_game.log.

Limite și reluare: doar pistolul are animație de reload reală (bakeuită în sursă); restul folosesc fallback-ul procedural nou. Verificarea mea a reticulului de lunetă în ADS pentru sniper_rifle în randarea offline nu a arătat overlay-ul (posibil artefact de timing al scriptului de test, nu al jocului — verify_revive_perspective.gd confirmă mecanismul funcțional pentru old_rifle, același cod se aplică la sniper_rifle); utilizatorul ar trebui să confirme vizual overlay-ul de lunetă în joc. Nu s-a făcut commit/push la acest lot.

### Corecție cătare — sights vechi plutind peste armele noi — 5 octombrie 2026

Cerere/bug raportat: cătările procedurale (puncte+cutii metalice) rămăseseră din sistemul vechi și se suprapuneau peste noile modele sculptate, "nu se vede bine deloc". Cauza: `first_person_weapon.gd._equip()` calcula înălțimea cătării din cel mai înalt punct al ÎNTREGULUI model (`top`, scanat peste toate mesh-urile) — pe cutiile vechi, mica geometrie dreptunghiulară făcea ca acel punct să fie aproape de țeavă; pe modelele sculptate noi, patul puștii/cureaua/alte piese ridicate împingeau `top` mult deasupra țevii reale, iar cătarea plutea departe de armă.

Reparație:
- Înălțimea cătării se calculează acum din Y-ul marker-ului `Muzzle` (deja poziționat corect per-armă la pasul anterior), nu din scanarea întregului model.
- Cătarea (post spate + post față) e plasată proporțional de-a lungul liniei reale țeavă-mâner (22%/94% din distanța către muzzle), nu la offset-uri Z fixe calibrate pe pistolul vechi.
- Dimensiuni reduse semnificativ (cutii/puncte ~2-3× mai mici) — citesc acum ca o cătare fină, nu bloc metalic masiv.
- Armele cu `sight_type=="scope"` (old_rifle, sniper_rifle) nu mai primesc deloc cătare fizică — oricum folosesc reticulul 2D la ochire; înainte primeau cătare oricum, vizibilă doar la hip-fire, inutil și predispusă să arate rupt.

Verificat: reimport curat; run_headless_tests.ps1 **430 checks, 0 failures** (inclusiv testul explicit de aliniere a cătării pistolului în ADS, care depinde de exact 3 noduri SightDot generate corect — comportament păstrat). Recapturat vizual toate cele 7 arme cu tests/preview_weapons.gd: cătările stau acum lipite de țeavă pe toate cele 5 arme cu iron sight, iar old_rifle/sniper_rifle sunt complet curate. Joc redeschis cu fereastră, pornire fără erori.

Fișier modificat: actors/hunter/first_person_weapon.gd (doar secțiunea de calcul/plasare cătare din `_equip()`). Nu s-a făcut commit/push.

### Aliniere ADS, balans, sunete reale și 6 arme noi — 5 octombrie 2026

Cerere: (1) pistolul nu era centrat la ADS, mult prea sus; (2) old_rifle n-ar trebui să aibă lunetă; (3) beehive ar trebui să fie automat și să tragă mai repede; (4) sunete de glonț "pe bune" pe toate armele; (5) 5-6 arme noi "misto" cu efecte tari. Separat, utilizatorul a mai cerut relief variat (munți/dealuri/ape) pentru hărți — netratat în această secțiune, vezi nota de la final.

**Aliniere ADS** — cauza reală avea două părți, nu doar formula de cătare din sesiunea trecută:
- Unealta mea de test (tests/preview_weapons.gd) avea un bug: apela manual `set_aiming()`, dar `camera_rig._process()` rulează automat în fiecare frame și suprascria `aiming` din input-ul real (neapăsat) — randările "ADS" anterioare erau de fapt tot hip-fire. Reparat cu `Input.action_press("aim")`/`action_release` + `Input.mouse_mode=CAPTURED`, ca inputul real să fie citit corect.
- Cu testul reparat, confirmat vizual: toate armele cu cătare de fier stăteau mult prea aproape/centrate greșit. Cauze reale: distanța de ADS (`aim.z=-0.5`, aproape identică cu hip `-0.56`) nu trăgea arma suficient înapoi când era centrată → mărită la `-0.72`. Formula de înălțime a cătării (`muzzle_y+.03` din sesiunea trecută) nu reflecta corect vârful real al țevii/receptorului pentru fiecare model → înlocuită cu o scanare de geometrie restrânsă la zona țeavă/receptor (între mâner și 85% din distanța spre muzzle), excluzând patul puștii.
- old_rifle avea nevoie de `ads_fov` mai mare (48→58) după ce a devenit iron sight (nu mai are zoom de lunetă).
- Verificat empiric cu randări reale (nu doar calcul): toate cele 13 arme (vechi+noi) au cătarea/reticulul corect centrat la ADS.

**old_rifle fără lunetă**: `sight_type` schimbat din "scope" în "iron", `ads_fov` 24→58. Testul `verify_revive_perspective.gd` care cumpăra old_rifle special pentru verificarea lunetei a fost mutat pe `sniper_rifle` (acum singura armă cu lunetă reală, cum a fost gândit inițial).

**beehive automat/rapid**: era deja `automatic=true`, dar `cooldown` redus 0.12→0.075 (de la ~8.3 la ~13.3 focuri/secundă) pentru senzația de "stup" cerută.

**Sunete reale de glonț**: toate cele 7 arme vechi + toate cele 6 noi au acum înregistrări reale (nu placeholder/sintetizate), cu excepția railgun/raygun (sintetizate, intenționat — n-are sens un "glonț real" pentru arme energetice sci-fi). Surse: opengameart.org (accesibil, spre deosebire de itch.io/quaternius.com/kenney.nl, blocate de Zscaler) — "Gunshot Sounds" (4 înregistrări reale: CZ-52, Mosin Nagant, SKS, shotgun; licență reală CC-BY 3.0/Vincent Sevedge, verificată din fișierul de licență din arhivă, NU CC0 cum sugera rezumatul inițial AI al paginii) și "The Free Firearm Sound Library" (194MB, 81 fișiere pe 40 de arme reale, CC0 per pagina de submisie). Toate sursele erau înregistrări brute de 6-20 secunde (focuri multiple/reverb) — extrase cu scripturi Python (work/sound_sources/extract_shots.py, extract_lib_shots.py) care găsesc vârful cel mai tare (impulsul de foc), taie o fereastră în jurul lui, reduc la mono, resamplează la 44100Hz și normalizează.

**6 arme noi**, aceeași metodologie de sourcing/integrare ca sesiunea anterioară (Quaternius, poly.pizza, wrapper-e subțiri cu rotație/scară/poziție calculate din bounding box real măsurat în Godot):
| Armă | Model sursă | Sunet | Rol |
| --- | --- | --- | --- |
| Revolver | Quaternius Revolver (Ultimate Guns) | S&W 642 (real) | daune mari, foc lent, 6 gloanțe |
| Pușcă de asalt | Quaternius Assault Rifle (Ultimate Guns) | AK-47 (real) | automată, cadență mare |
| Railgun | Quaternius Sniper Rifle (Scifi pack) | sintetizat (charge+crack) | lunetă strânsă (17° fov), daune foarte mari, foc rar |
| Pistol laser | Quaternius Ray Gun (Scifi pack) | sintetizat (pew descrescător) | semi-auto rapid, cadență mare |
| Mitralieră în lanț | Quaternius Submachine Gun variant (Ultimate Guns) | Carl Gustav M45 (real) | cadență extremă (~16,6/s), daune mici |
| Nova | Quaternius Shotgun (Ultimate Guns) | Nova pump shotgun (real) | 10 alice, evantai larg |

Adăugat câmp nou `effect_color: Color` pe `WeaponDefinition` (implicit portocaliu, ca înainte); `hunter_combat.gd` (`_flash`/`_tracer`/`_impact`) colorează acum flash-ul, scânteile, traseul și impactul cu culoarea armei — railgun albastru electric, raygun verde toxic, restul variații de cald/alb. Asta e "efectul tare" cerut: identitate vizuală distinctă per armă, nu doar reskin.

Fișiere principale: data/weapons/{revolver,ak_rifle,railgun,raygun,chain_smg,nova_shotgun}.tres (noi), actors/equipment/{aceleași 6}.tscn (noi), assets/weapons/stylized/{aceleași 6}.glb (noi) + ATTRIBUTION.md extins cu secțiune audio, data/definitions/weapon_definition.gd (effect_color), systems/combat/hunter_combat.gd (culoare pe efecte), data/equipment_catalog.gd (+6 în WEAPONS), data/localization/{ro,en}.json (+6 arme), data/weapons/old_rifle.tres (sight_type, ads_fov), data/weapons/beehive.tres (cooldown), actors/hunter/first_person_weapon.gd (aim distance, sight_y), tests/verify_revive_perspective.gd (old_rifle→sniper_rifle pentru testul de lunetă), tests/preview_weapons.gd (+6 arme, bug Input.action_press reparat).

Verificări locale efectiv executate:
- Import Godot 4.7.1 headless: exit 0 (o rulare izolată a dat exit code 5 fără text de eroare — reluată curat, posibil interferență tranzitorie de-a lungul extragerii concurente de 329MB; nereprodus la a doua încercare).
- run_headless_tests.ps1 complet: **436 checks, 0 failures** (progression a crescut de la 51 la 57 — exact cele 6 verificări noi "model and sound exist", generate automat din bucla peste EquipmentCatalog.WEAPONS, fără nicio modificare manuală de test necesară). Raport: tests/results/headless_20261005_144417_9fb3b0.
- run_network_tests.ps1 forest: toate cele 5 roluri, **189 checks, 0 failures** (exit code 1 al scriptului, artefactul cunoscut, nu o eșuare reală).
- Verificare vizuală reală (nu doar logică) prin tests/preview_weapons.gd, hip-fire ȘI ADS, pentru toate cele 13 arme: toate corect poziționate/orientate; cătarea/reticulul centrat corect la ADS pe toate; railgun confirmă vizual reticulul de lunetă funcțional (problema din sesiunea trecută era într-adevăr doar bug-ul din scriptul de test, nu din joc).
- Joc redeschis cu fereastră (Compatibility/Intel UHD620): pornire curată, fără erori în local_game.log.

Limite și reluare: Nu s-a făcut commit/push la acest lot masiv de schimbări (arme + sunete + modele). Fișierele sursă mari (194MB arhivă audio, modele brute) au fost șterse din work/ după procesare — nu ocupă spațiu în repo (work/ e oricum ignorat de Git).

### Relief variat — munți, dealuri, lac, plasare animale după pantă — 5 octombrie 2026

Cerere: ambele hărți să aibă relief variat (munți urcabili, dealuri), fiecare lume "să arate foarte foarte bine", animale plasate potrivit reliefului. Discutat și confirmat cu utilizatorul înainte de implementare: ambele hărți (nu doar pădurea), doar plasare inteligentă a celor 10 specii existente (fără specii noi), munți chiar urcabili (nu doar decor la orizont).

Arhitectura găsită înainte de schimbare: înălțimea terenului era zgomot Perlin simplu (un singur strat), fără munți reali; pădurea nu avea apă deloc; mlaștina avea deja un precedent bun — `animal_spawn()` căuta un punct unde înălțimea se potrivea cu `aquatic` al speciei (broaște/crocodili în apă). Mișcarea (vânător, animale, jeep) se bazează pe coliziunea fizică a mesh-ului generat, nu pe cod de mișcare separat, deci pante noi "funcționează" automat.

Implementare (world/forest/forest_map.gd, extins în world/swamp/swamp_map.gd):
- **Munți**: trei straturi noi de zgomot (`region_noise` low-freq pentru "unde sunt munți", `warp_noise` pentru domain warping ca să nu arate repetitiv, `ridge_noise` cu `1-abs(noise)` ridicat la putere pentru vârfuri ascuțite reale, nu dealuri rotunjite) combinate și mascate astfel încât contribuția de munte e **zero** până la distanța 110 de tabără și ajunge la amplitudine maximă (46 unități) abia dincolo de 260 — zona imediată de spawn/test rămâne byte-identică cu înainte.
- **Siguranța drumului pentru jeep**: drumul existent (calea sinusoidală `x=sin(z*.012)*28`) se întinde pe toată lungimea hărții, nu doar lângă tabără — fără protecție, ar fi trecut direct prin fețe de munte la z mare. Adăugată o atenuare a contribuției de munte în apropierea drumului (clar pe o rază de ~16-55 unități), verificată vizual: drumul rămâne în vale chiar și unde taie prin zona muntoasă.
- **Lac nou în pădure**: bazin circular (rază 72+26m tranziție) departe de tabără/drum, shader de apă nou (world/forest/forest_lake.gdshader, copie adaptată a celui de mlaștină cu estompare radială proprie ca să nu arate translucid pe uscat la colțurile planului). Crearea lacului e izolată într-o metodă `_build_lake()` suprascrisă ca no-op în SwampMap, care își păstrează propriul sistem de apă pe toată harta.
- **Dealuri la marginea mlaștinii**: aceeași rețetă (region+warp+ridge) adăugată peste `SwampMap.height_at()`, mascată să fie zero sub distanța 400 — nucleul umed (POI-uri, apă, drum) rămâne byte-identic; doar marginea exterioară (spre 600m) urcă în dealuri împădurite.
- **Pantă calculabilă**: `slope_at(x,z)` (diferențe finite pe `height_at`) nou pe ForestMap, moștenit de SwampMap.
- **Animale pe relief**: câmp nou `max_slope` pe `AnimalDefinition` (grade, implicit 90=nerestricționat), calibrat pe cele 10 specii (iepure 22°, căprioară 28°, mistreț 32°, lup 44°, urs 40° — pădure; șarpe 26° — mlaștină; restul mlaștinii rămân acvatice, nerestricționate de pantă). `ForestMap.animal_spawn()` nou (înainte nu exista la bază, doar la mlaștină) caută un punct din apropiere cu panta sub toleranța speciei. `SwampMap.animal_spawn()` extins similar pentru ramura neacvatică.
- **Vizual pe pantă/altitudine**: ambele shadere de sol (forest_ground.gdshader, swamp_ground.gdshader) primesc acum normala în spațiul lumii; amestecă stâncă pe pante abrupte și un ton palid pe vârfurile înalte ale pădurii — fără texturi noi, în același stil procedural.
- **Copaci/vegetație**: excluse din lac și de pe pante >48° la copacii pădurii (verificare ieftină doar de lac la vegetația ierboasă, fără calcul de pantă acolo, ca să nu încetinească streaming-ul per-sector).
- `floor_max_angle` (CharacterBody3D) lăsat la valoarea implicită Godot (45°) — nu a fost nevoie de ajustare; produce natural atât povârnișuri urcabile cât și vârfuri cu adevărat neescaladabile.

Fișiere principale: world/forest/forest_map.gd, world/forest/forest_ground.gdshader, world/forest/forest_lake.gdshader (nou), world/swamp/swamp_map.gd, world/swamp/swamp_ground.gdshader, data/definitions/animal_definition.gd (+max_slope), data/animals/{rabbit,deer,boar,wolf,bear,snake}.tres (+max_slope), tests/preview_terrain.gd (nou, unealtă de verificare vizuală reutilizabilă).

Verificări locale efectiv executate:
- Import Godot 4.7.1 headless: exit 0, fără erori, la ambele reimportări (inclusiv după fix-ul de drum).
- run_headless_tests.ps1 complet, de două ori (înainte și după fix-ul de drum): **436 checks, 0 failures** ambele dăți — inclusiv `forest.height_at(0,0)==0` ("camp terrain flat"), `trees.size()>5000`, alinierea normalei terenului, `swamp.height_at(0,0)>1` ("arrival is dry and elevated"), determinismul mlaștinii pe doi peeri, și mixul de puncte apă/mal — toate păstrate exact, fără nicio modificare de test necesară. Raport final: tests/results/headless_20261005_151031_af8990.
- run_network_tests.ps1 pe forest și swamp: toate cele 5 roluri, **189 checks, 0 failures** pe fiecare hartă.
- Verificare vizuală reală prin tests/preview_terrain.gd (zbor aerian peste centura de munți, peste lac, peste marginea mlaștinii): munți cu vârfuri înzăpezite vizibile la orizont, lac curat într-o vale lângă pădure, drum confirmat rămânând în vale prin zona muntoasă după fix. Marginea nouă de dealuri a mlaștinii nu a fost prinsă clar în cadru (camera nu a ajuns suficient de departe) — codul e simetric cu cel al pădurii (aceeași rețetă, deja testat logic), dar nu a fost confirmată vizual la fel de dramatic ca pădurea.
- Joc redeschis cu fereastră (Compatibility/Intel UHD620): pornire curată, fără erori.

Limite și reluare: dealurile de la marginea mlaștinii nu au fost verificate vizual la fel de atent ca munții pădurii (doar logic, prin teste). Fără specii noi de animale (ales explicit de utilizator). Nu s-a făcut commit/push.

### Hartă procedurală — sămânță aleatoare automată, sincronizată în rețea — 5 octombrie 2026

Cerere: harta să se genereze diferit de fiecare dată, dar "cu sens" (nu haotic). Precizare explicită a utilizatorului: complet automat, fără input manual de sămânță de la nimeni — să se aplice automat la toți cei din sesiune.

Context găsit: `ForestMap.SEED`/`SwampMap.SWAMP_SEED` erau constante fixe la compilare — harta era mereu identică. Protocolul de încărcare (`_begin_loading`→RPC `_prepare_world`→`world_router.prepare`→`ForestMap.build()`) exista deja și era exact punctul potrivit de injectat o sămânță: gazda decide, trimite la toți prin RPC existent, toată lumea construiește local din aceeași sămânță (coliziune, apă, poziții de animale — toate deterministe din sămânță+poziție, nu din RNG runtime).

Implementare:
- `ForestMap`: nou `func set_seed(value)` — resetează cele 4 straturi de zgomot (teren, regiune, warp, ridge) dintr-o singură valoare; `_ready()` apelează `set_seed(SEED)` ca implicit (nimic nu se schimbă pentru cine instanțiază o hartă direct, ex. teste/previzualizări). `SwampMap` suprascrie `set_seed()` ca să-și păstreze frecvența proprie de zgomot.
- `WorldRouter.prepare(id,epoch,map_seed=0)`: după instanțiere, dacă e hartă de vânătoare și s-a primit o sămânță reală, o aplică pe hartă înainte de `build()`.
- `NetworkSession._begin_loading()`: gazda generează `randi()` (garantat nenul) **doar** când se pornește o hartă de vânătoare (nu pentru tabără), îl include în RPC-ul `_prepare_world` deja existent — niciun mesaj nou de rețea.
- **Reconectare**: un jucător care se alătură în timpul unei vânători active trebuia să primească *aceeași* sămânță ca restul, altfel terenul lui local (coliziune, poziții) ar fi desincronizat de la ceilalți. Găsit acest caz separat (`_welcome()`, folosit la conectare/reconectare) — adăugat `active_map_seed` ca stare de sesiune, inclus în `_snapshot()` (deja transmis la welcome), aplicat la `world.prepare_world()` acolo.
- `game/main.gd.prepare_world()` capătă al treilea parametru opțional, pur pass-through.

Fișiere principale: world/forest/forest_map.gd, world/swamp/swamp_map.gd, world/world_router.gd, core/network_session.gd, game/main.gd, tests/verify_swamp.gd (testul de determinism actualizat să aplice sămânța reală a hărții live pe instanța "twin", nu una implicită — singurul test afectat).

Verificări locale efectiv executate:
- Import Godot 4.7.1 headless: exit 0.
- run_headless_tests.ps1 complet: **436 checks, 0 failures** — inclusiv testul de determinism reparat și toate invarianții de teren (tabără plată, sosire uscată în mlaștină) păstrați pentru orice sămânță.
- run_network_tests.ps1 pe forest și swamp: toate cele 5 roluri, **189 checks, 0 failures** pe fiecare hartă — inclusiv scenariile explicite de reconectare ("same profile reconnects", "late join finishes forest before host ends test"), care acum depind de propagarea corectă a sămânței.
- tests/verify_random_terrain.gd (nou, unealtă reutilizabilă): **6 checks, 0 failures** — confirmă direct: tabăra rămâne plată la orice sămânță (ambele hărți), sămânțe diferite produc teren vizibil diferit, aceeași sămânță reproduce exact același teren pe o instanță separată (determinism), sosirea în mlaștină rămâne uscată la orice sămânță, și o expediție reală din joc primește automat o sămânță nenulă reală fără input manual.
- Joc redeschis cu fereastră: pornire curată, fără erori.

Limite și reluare: nu s-a verificat vizual (captură de ecran) că două vânători consecutive chiar arată diferit în joc — doar verificat logic/numeric (valorile de înălțime diferă). Nu s-a făcut commit/push.

### Actualizare locală, citire istoric și pornire — 5 octombrie 2026

Cerere: descărcarea ultimei versiuni din GitHub, deschiderea jocului și citirea lucrărilor făcute azi cu Claude.

- Clonă nouă, inițial curată, în `C:\Users\Razvan\Documents\Codex\2026-10-05\incarca-mi-tot-jocul-in-repo-3\work\joc-vanatoare`, pe `main` la `ec228b4290d69bf0261cbdac3d959eee899321df`, identică cu `origin/main` la descărcare.
- Citite jurnalul, istoricul celor trei commit-uri din 5 octombrie și codul relevant: importul jocului (`521e5b9`), animalele articulate/stilul toon (`7d4df82`) și armele/HUD-ul/relieful cu sămânță sincronizată (`ec228b4`). Ultimele două commit-uri îl menționează pe Claude Opus 5 drept coautor. Notele istorice „nu s-a făcut commit/push” descriu starea acelor sesiuni; loturile există acum în istoricul publicat.
- Import local cu Godot 4.7.2: prima încercare izolată a întâmpinat restricții de scriere în AppData; reluarea aprobată s-a încheiat cu exit 0, fără erori în `work/godot-import.log` din folderul acestei conversații.
- Lansat jocul cu motorul existent, Vulkan/Forward+ pe NVIDIA GeForce RTX 3050 Ti. Meniul complet în română a fost confirmat vizual, fără erori în logul de pornire. Utilizatorul a oprit automatizarea UI prin Escape în timpul tentativei de intrare în tabără; rezultatul acelui click nu este confirmat. Nu s-a continuat controlul UI.
- Nu au fost rerulate suitele gameplay/rețea. Cele 436 verificări headless, 189 verificări pe fiecare hartă și 6 verificări ale terenului aleator din secțiunile anterioare sunt rezultate istorice ale sesiunii Claude, nu rezultate locale noi.
- Singura modificare intenționată este această completare a `CONTEXT_PROIECT.md`; gameplay-ul este neschimbat. Importul Godot a lăsat 241 fișiere `.import` marcate modificate și `tests/verify_random_terrain.gd.uid` neversionat. Inspecția `git diff --numstat -- '*.import'` nu arată diferențe de conținut după normalizarea Git; nu au fost restaurate sau editate manual.
- Fără commit/push. Rămân inspecția gameplay-ului de către utilizator și deciziile deja consemnate despre deblocarea automată a armelor pentru testare, salvarea progresului și integrarea Steam.

### Apă naturală, texturi CC0 și fizică de contact — 5 octombrie 2026

Cerere: căutare pe internet și îmbunătățirea aspectului, texturilor și fizicii apei din lac și mlaștină.

- Surse consultate: asset-ul CC0 „Seamless looping waves heightmaps” de zookeeper (OpenGameArt), NVIDIA GPU Gems despre valuri geometrice și normale fine, documentația oficială Godot pentru depth/refracție și formula F0 din sursa renderer-ului. Normalele provin din două cadre sursă 512×512 păstrate în repo; spuma este noise periodic original. Proveniență/hash-uri: `assets/art/water/{ATTRIBUTION.md,source_receipt.json}`; actualizat și indexul general `assets/art/ATTRIBUTION.md`. Generator reproductibil: `tools/asset_pipeline/build_water_textures.py`, cu `--check` fără scriere; verificarea exactă a rezultatului a trecut.
- Material comun în `world/effects/natural_water.gdshaderinc`, configurat separat de shader-ele Forest/Swamp: valuri mici și normale animate, reflexii cer/soare, Fresnel corect pentru apă, refracție cu respingerea obiectelor din față, absorbție după adâncime și spumă la mal/contact. Corecție la review: `SPECULAR=.3571` deoarece Godot folosește `F0=.16*SPECULAR²`. Detaliul fin și undele de contact se calculează pe pixeli pentru a evita aliasing-ul mesh-ului.
- Lacul are acum fund real, traversabil, cu adâncime maximă 1,15m și mal protejat împotriva șanțurilor produse de sămânțele aleatoare. `water_depth()`/`water_submersion()` sunt comune hărților; punctele uscate sau deasupra apei nu primesc rezistență nouă. Comportamentul existent al noroiului și podețelor din mlaștină este păstrat.
- Hunter-ul încetinește după imersiune; jeep-ul primește drag și susținere modestă în patru puncte, numai pe host. Loading-ul, predicția și replicarea existente sunt păstrate. `world/effects/water_interaction.gd` reconstruiește local pași/urme din pozițiile replicate, fără RPC-uri noi: maximum 8 evenimente, durată 5s, curățare la loading/travel. Nu există comenzi noi sau controller de înot.
- Fișiere afectate: `world/forest/{forest_map.gd,forest_lake.gdshader}`, `world/swamp/{swamp_map.gd,swamp_water.gdshader}`, `world/effects/{natural_water.gdshaderinc,water_interaction.gd}`, `actors/hunter/hunter.gd`, `actors/vehicles/hunting_jeep.gd`, asset-urile/pipeline-ul de apă, `tests/{verify_water.gd,preview_water.gd}`, `docs/water.md` și acest jurnal.
- Validare locală Godot 4.7.2: runner-ul complet cu cele opt suite existente, **436 checks, 0 failures**, exit 0; raport `tests/results/headless_20261005_202106_0c8856`. Prima tentativă în sandbox a rămas blocată înainte de generarea rapoartelor; a fost oprită și reluată cu permisiunile aprobate și executabilul non-console. Acea tentativă nu reprezintă un eșec al verificărilor suitei.
- Verificare focalizată `tests/verify_water.gd`: **22 checks, 0 failures**. Deplasare reală: uscat 4,858m / lac 2,714m; viteză jeep în rulare liberă: uscat 5,485m/s / apă 4,522m/s; cădere fără/cu susținere: 0,178m / 0,081m. Confirmate contactul, adâncimea limitată/malul uscat pe sămânțele testate, determinismul, expirarea undelor, loading-ul, stabilitatea jeep-ului și lipsa simulării locale pe client.
- Preview real Forward+ pe RTX 3050 Ti: **4 capturi**, exit 0, fără erori, în `outputs/` al conversației. Apa Forest, vedere de sus, wake și mlaștina au fost capturate din scenele reale; selecția punctului umed verifică și vecinătatea. Instantanee de aproximativ 42–60 FPS, nu benchmark de performanță. Refracția capturează numai geometria opacă; reflexiile sunt din cer/soare; nu este un solver de fluid.
- Preview Compatibility/OpenGL 3.3 pe RTX 3050 Ti: exit 0, fără erori de shader/script; captura lacului inspectată și corectă. Log: `work/water-compat.log` din conversație. Snapshot-uri FPS 60 lac / 2 vedere aeriană / 28 wake / 54 mlaștină; influențate de compilare și încărcare, fără concluzie despre performanța stabilă.
- Rețea ENet Forest, toate cele cinci roluri: **189 checks, 0 failures**, exit 0; raport `tests/results/run_20261005_202527_7fae98`.
- Rețea ENet Swamp, toate cele cinci roluri: **189 checks, 0 failures**, exit 0; raport `tests/results/run_20261005_202702_c315c6`. `tests/verify_random_terrain.gd`: **6 checks, 0 failures**, exit 0; log `work/water-random-terrain.log` din conversație. Total în cele cinci rulări de verificare: **842 checks, 0 failures** (436 + 22 + 6 + 189 + 189).
- Recapturarea Forward+ după reglajul final al malului este încheiată: toate cele patru capturi în `outputs/`, `WATER_PREVIEW_DONE`, log fără erori (`work/water-final-preview.log` din conversație). Instantanee finale 60 / 46 / 47 / 60 FPS, fără pretenție de benchmark. Validările planificate sunt finalizate. Fără commit/push. Limitele și pașii de reproducere sunt în `docs/water.md`.

### Jupuire manuală și sediment sub apă — 5–6 octombrie 2026

Cerere: recuperarea manuală a pielii/carapacei după vânătoare, cu fiecare tăietură efectuată de jucător, dificultate după specie și recompensă după precizie; nisip natural pe fundul lacului și noroi sub apa mlaștinii. Sesiunea începută pe 5 octombrie a fost reluată și validată complet pe 6 octombrie.

- Moartea lasă un corp și nu acordă automat loot. E la maximum 2,8 m pornește lucrul; fiecare Click stânga/Space consumă o rundă de timing, fără progres prin așteptare sau menținere. Cele zece specii existente cer 2–8 tăieturi reușite, cu perioade 2,60–1,80 s și benzi 34–16%. Nu s-au adăugat specii. Țestoasa are etape pentru carapace; celelalte pentru piele. Detalii și tabel: `docs/harvesting.md`.
- Hostul validează corpul, distanța/obstacolele, HP, capacitatea, timpul simulat, token-ul, runda și `world_epoch`; clientul trimite intenții. Corpul are un singur ocupant; progresul/greșelile persistă la anulare. Damage-ul, plecarea, doborârea, meniurile/loading-ul și disconnect-ul întrerup lucrul. Heartbeat-ul de focus expiră, iar E/Esc/WASD anulează curat. Focul, saltul, revive-ul și condusul simultan sunt protejate. Cadavrele neocupate expiră după 10 minute; bugetul total este 80, cu eliminarea celor mai vechi neocupate și repopulare după numărul celor vii.
- Recompensa intră direct în ghiozdan la final: fără greșeli 120%, 1–2 greșeli 100%, minimum 3 greșeli 65% din prețul de bază, rotunjit. ID-urile validate `base__q1/2/3` păstrează calitatea prin inventar, portbagaj, vânzare și reconectare; cargo își păstrează proprietarul stabil. Spațiul este verificat la început și la final; corpul rămâne recuperabil dacă ghiozdanul se umple. Replicarea transmite acum și roster-ul gol după consumarea ultimului cadavru.
- Prezentare: cameră stabilă spre corp, panou compact cu ac mobil/bandă sigură, etape, progres, feedback perfect/bine/ratat, valoare estimată, dificultate și spații necesare. Cuțitul/mâna sunt geometrie procedurală originală, fără cumpărare, cu o mișcare unică de 225 ms după ACK `perfect/cut/miss`; fără răni grafice sau animație automată. Arma first person este ascunsă și în procesul copilului, apoi restaurată. Protecția de input împiedică ultima tăietură să tragă ori să sară; retry-ul după apăsarea prea devreme și expirarea rezultatului sunt corectate. Instrucțiuni/nume/calități RO/EN, inclusiv Esc pentru anularea lucrului.
- Sediment: Forest are nisip procedural numai în bazin și la mal, cu granule/ondulații filtrate și umezeală; Swamp reutilizează scan-ul CC0 Poly Haven `brown_mud_03` pentru noroi brun sub apă. Fără modificarea coliziunii, adâncimii, noroiului sau podețelor. Hash-ul `uint` din `world/effects/sediment_surface.gdshaderinc` elimină discontinuitățile GPU ale zgomotului anterior bazat pe sinus. Diagnostic A/B: `tests/diagnose_sediment.gd`. Surse și detalii: `docs/water.md`, `assets/art/ATTRIBUTION.md`.
- Fișiere principale: `core/network_session.gd`, `actors/animals/wildlife_animal.gd`, `actors/hunter/{hunter,first_person_weapon,harvest_tool}.gd`, `systems/{combat/hunter_combat,inventory/hunter_inventory}.gd`, catalogul/definițiile animalelor și loot-ului, cele zece resurse animale, `game/main.gd`, `world/interactables/animal_harvest_interactable.gd`, `ui/harvest/harvest_panel.gd`, pickup/shop și traduceri; shader-ele de sol Forest/Swamp și include-ul de sediment; teste/preview-uri și documentația de recoltare/apă. Nu s-a făcut commit/push.

Verificări finale locale Godot 4.7.2:

- Import curat. Nouă suite headless: **532 checks, 0 failures** (42 + 45 + 56 + 57 + 37 + 48 + 51 + 103 + 93), raport `tests/results/headless_20261006_095802_79fc1a`. Cele 93 de verificări harvest includ economia/calitatea, co-op, input-ul real, expirarea UI și protecția first person.
- ENet real Forest: **208 checks, 0 failures**, raport `tests/results/run_20261006_100227_192ac5`; Swamp: **208 checks, 0 failures**, raport `tests/results/run_20261006_100432_6109c6`. Ambele: host 54 / client1 50 / client2 47 / client3 54 / extra 3, cu refuzarea celui de-al cincilea și recoltă concurentă/anti-duplicare.
- `verify_water.gd`: **22 checks, 0 failures**; `verify_random_terrain.gd`: **6 checks, 0 failures**. Totalul celor cinci rulări finale: **976 checks, 0 failures** (532 + 208 + 208 + 22 + 6).
- Preview Forward+ final pe RTX 3050 Ti: `outputs/jupuire_interactiune.png`, `jupuire_mini_joc.png`, `jupuire_calitate.png` din conversație, cu cuțit/UI/recompensă și protecții verificate. Șase capturi de apă includ nisipul neted și noroiul scanat; shader-ele finale au fost inspectate. Instantaneele FPS nu sunt benchmark.
- Compatibility/OpenGL 3.3: șase capturi, `WATER_PREVIEW_DONE` și log fără erori în `work/sediment-compat.log` din conversație. Codul de ieșire nu a fost returnat; nu este afirmat. Capturile și markerul confirmă preview-ul terminat.
- Tentative intermediare au expus fixture-uri: în testul Swamp, hunter-ul rămânea cu `control_enabled=false`; corectat înainte de reluare. Fixture-ul jeep din ENet a fost mutat la sosirea garantat plată și așteaptă deplasarea reală prin polling, eliminând eșecurile de mediu/timing. Rulările complete finale de mai sus au trecut; tentativele anterioare nu intră în totalul 976.

Limite: recoltarea este un mini-joc de precizie, fără simulare anatomică completă. Hostul punctează la primirea intenției, fără compensarea latenței; WAN/latența mare nu sunt validate. Apa păstrează refracția scenei opace și reflexii cer/soare, fără solver de fluid. Economia persistentă, Steam și host migration rămân neimplementate.

Cerere nouă: utilizatorul a furnizat `C:/Users/Razvan/Downloads/weapon_pack_of_10100_part_1.glb`. Implementarea și validarea finalizate sunt descrise în secțiunea Arme OBUR de mai jos.

### Arme OBUR și cuțit Gerber — 6 octombrie 2026

Cerere: înlocuirea completă a modelelor armelor existente cu pachetul GLB furnizat de utilizator. Originalul de 2.241.280 bytes are metadate explicite: OBUR Games, „Weapon Pack of 10/100 Part 1”, sursa Sketchfab și CC BY 4.0. Este păstrat în `assets/weapons/obur/source/weapon_pack_of_10100_part_1.glb`, cu `.gdignore`, atribuire și receipt SHA-256; nu s-a cumpărat un pack. Toate cele 13 arme folosesc modelele noi, iar integrarea și validarea finală sunt încheiate.

- `tools/asset_pipeline/build_obur_weapons.py` folosește numai biblioteca standard Python, elimină transformările de prezentare și buffer-ele/imaginile nefolosite, păstrând geometria, UV-urile, paleta și materialele originale. Extrage 11 GLB-uri; `obur_weapon_fit.json` generează 13 wrapper-e, marker-ele măsurate Muzzle/Grip/SupportGrip/FrontSight/RearSight și nuanțări discrete. `--check` reproduce byte-for-byte cele 11 modele, 13 scene și receipt-ul, fără scriere.
- Transformarea are bază cu determinant pozitiv: +X brut → −Z, +Z brut → +Y; MG42 nivelată cu 18,013°. Muzzle-ul este verificat față de vertex-urile sursă, iar mâinile folosesc marker-ele de prindere. Toate cele 13 rădăcini au metadata OBUR. Materialele metal/plastic sunt păstrate; tint-urile sunt copii locale fără modificarea materialelor partajate. Lumina first person redusă la energie 0,14.
- Mapping: `rusty_pistol`→Baretta 93R; `old_rifle`→SCAR-L de patrulare semiautomată cu cătare mecanică; `double_barrel`→Maverick compact; `scrap_blaster`→Maverick Scrap; `beehive`→UZI; `sniper_rifle`→G36 Marksman; `thunder_tube`→M72 LAW fictiv electromagnetic; `revolver`→Tarran Tactical; `ak_rifle`→SCAR-L; `railgun`→G36 fictiv de energie; `raygun`→Baretta fictiv laser; `chain_smg`→MG42; `nova_shotgun`→Maverick 88. ID-urile, statisticile, prețurile, upgrade-urile și audio sunt păstrate. Denumirile/descrierile RO/EN reflectă sursele; pachetul nu pretinde modele de revolver, shotgun cu două țevi, sniper dedicat ori SF.
- Cătările native primesc doar puncte emissive mici, fără box-uri procedurale suprapuse. Înălțimile front/rear și pitch-ul ADS aliniază raza camerei; offset-uri native 1,5 mm și spacing MG42 calibrat, în locul offset-urilor legacy de 8/12 mm. Hip-distance la armele lungi ține cont de limita posterioară, evitând near-plane clipping. Pachetul nu are animații; reload-ul procedural de coborâre/revenire rămâne pentru toate cele 13 arme, cu duratele lor existente.
- Gerber LMF din sursa reală înlocuiește lama/mânerul procedural de recoltare; mâinile originale și tăietura unică de 225 ms după ACK perfect/cut/miss rămân. Grenada și racheta sunt extrase, fără arme jucabile noi; `Cylinder.016` este proiectil, nu amortizor.
- `CampMenu` afișează în footer linkuri către pachetul original, OBUR Games și CC BY 4.0, cu „Modele adaptate” / „Adapted models”, inclusiv în export. Credite: `assets/weapons/obur/ATTRIBUTION.md`; modelele Quaternius anterioare sunt marcate legacy/nefolosite, iar creditele audio rămân în `assets/weapons/stylized/ATTRIBUTION.md`. Ghid: `docs/weapons_obur.md`; actualizate și README-ul pipeline-ului/documentația de recoltare.

Verificări și stare de reluare:

- Builder-ul cu `--check` verifică exact toate output-urile de mai sus. `tests/preview_weapons.gd` capturează 40 imagini: creditul din meniu și hip/ADS/reload pentru 13 arme, plus 26 verificări ale muzzle-ului și alinierii camerei/reticulului.
- Un preview intermediar a depistat baza rând/coloană transpusă în serializarea text `Transform3D`; corectată și confirmată în GPU. Alte 11 eșecuri ADS erau false, din comparația viewport-ului fizic cu cel logic; verificarea folosește acum `get_visible_rect()`. Rulările intermediare nu intră în totalul final.
- Runner headless final după toate ajustările: **532 checks, 0 failures**, raport `tests/results/headless_20261006_103500_f7094f`, nouă suite, fără erori. Rezultatul intermediar `headless_20261006_102903_470f89` este înlocuit de această validare.
- ENet final Forest: **208 checks, 0 failures**, raport `tests/results/run_20261006_103650_911182`; Swamp: **208 checks, 0 failures**, raport `tests/results/run_20261006_103948_c2a3e0`. Ambele au host 54 / client1 50 / client2 47 / client3 54 / extra 3; logurile de eroare sunt curate.
- Preview Forward+ final: **40 capturi și 26 verificări, 0 eșecuri**, `WEAPON_PREVIEW_DONE qa_failures=0`, exit 0, log `work/obur-game-preview-final.log` din conversație. Cele 13 muzzle-uri corespund vertex-urilor reale, cele 11 cătări mecanice se aliniază cu camera, iar cele două reticule de lunetă apar. Capturile hip/ADS/reload și creditul din meniu au fost inspectate; FPS nu este benchmark. Livrate `outputs/arma_SCAR_L.png` și `arma_SCAR_L_ochire.png`.
- Preview final harvest cu Gerber: toate cele trei capturi în `outputs/`, `HARVEST_PREVIEW_DONE carcass=25 quality_loot=["deer_pelt__q1"]`, exit 0, fără erori în `work/obur-harvest-preview.log` din conversație. Comportamentul tăieturii, feedback-ul și calitatea sunt păstrate.
- Builder `--check` byte-for-byte, cele **265 chei RO/EN** și verificarea whitespace au trecut. Totalul lotului de arme: **974 verificări, 0 eșecuri** (532 + 208 + 208 + 26), fără dublarea rulărilor intermediare. Cele 22 verificări apă și 6 teren sunt consemnate în lotul precedent, nu sunt prezentate ca rerulări după arme.
- Joc redeschis normal, fereastră `Hunt Together — Prototype (DEBUG)` activă, pornire fără erori în `work/obur-live-game.log` din conversație. Nu s-a făcut commit/push. Nu rămân verificări necesare în acest lot.

Limite: modelele OBUR sunt statice; animațiile reload/cuțit sunt prezentare procedurală, iar variantele de energie păstrează mecanici fictive. Nu s-au adăugat mecanici de grenadă/rachetă. Pachetul are opt modele de arme de foc, folosite cu variante în cele 13 sloturi existente; nu este un pachet cu 13 arme distincte. Modelele vechi sunt păstrate ca asset-uri legacy, fără referințe în scenele armelor active. WAN/latența mare și performanța pe GPU-uri mai slabe nu sunt stabilite de verificările locale.

### Jupuire trasată cu cuțitul — 6 octombrie 2026

Cerere: jupuirea să devină mecanica principală a jocului și să fie „mult mai mișto". Utilizatorul a ales varianta hibridă (trasare cu mouse-ul pentru incizii, ritm pentru smulgerea finală) și a cerut explicit ca în co-op să rămână un singur vânător pe cadavru, ca până acum.

Mecanica veche era un singur click cronometrat per tăietură, identic pentru orice specie, fără legătură cu corpul animalului. Acum lucrul are trei etape pe același cadavru: incizii trasate, arce de separare trasate și smucituri cronometrate la final.

- `data/harvest_pattern.gd` (nou, `HarvestPattern`) este geometria partajată: `plan` împarte `harvest_strokes` în cele trei etape, `points` generează curba Catmull-Rom din `animal_id`+etapă+pas, iar `project`/`sample`/`length` dau interogările de arc. Totul pur și determinist, deci hostul și clientul construiesc exact aceeași linie fără s-o trimită prin rețea, iar același cadavru păstrează aceleași linii după renunțare.
- `core/network_session.gd`: `_harvest_blade` este noul judecător. Clientul trimite doar `blade`/`blade_down` prin `_accept_input`, la rata normală de input; hostul regenerează curba și măsoară el abaterea, viteza și avansul. Eșantioanele sunt interpolate pe segment, deci o mișcare bruscă nu sare peste porțiuni. `_finish_harvest_step` încheie un pas; `_harvest_stroke` rămâne, dar doar pentru etapa de tragere.
- Calitatea nu mai numără greșeli, ci acumulează uzură în miimi pe cadavru (`harvest_wear`, replicat în snapshot): ieșirea din traseu proporțional cu abaterea și distanța parcursă, tragerea peste limita de viteză, ridicarea cuțitului la mijlocul unei incizii (70) și ratarea unei smucituri (150). `AnimalCatalog.stars_from_wear` dă pragurile 60/220/430/680 pentru 5★…1★, iar `harvested_loot_wear` minează același `<loot>__s<stele>`, deci prețurile 150/120/100/50/10% și păstrarea calității prin ghiozdan, portbagaj, serializare și vânzare rămân neschimbate.
- `AnimalDefinition.harvest_trace` derivă toleranța și limita de viteză din `harvest_window`, deci o specie e coerent ușoară sau brutală în toate etapele, fără modificări în `.tres`. Toleranța scade la 78% și viteza la 86% spre finalul corpului, pe aceeași curbă de presiune ca banda de ritm. Iepure/broască: 3 pași, toleranță .180; crocodil străvechi: 14 pași, toleranță .080.
- `ui/harvest/harvest_panel.gd` desenează acum zona de piele cu traseul, banda reală de toleranță, porțiunea deja tăiată, lama virtuală și bara de integritate cu pragurile de stele marcate. Mișcarea mouse-ului captat conduce lama; banda de ritm apare doar la etapa finală. Panoul s-a mutat în dreapta ca să nu acopere planul apropiat 3D.
- `actors/hunter/harvest_tool.gd` și `harvest_hide.gdshader`: cuțitul urmărește în timp real lama pe suprafață, incizia se desenează ca panglică 3D exact pe punctele tăiate, iar shader-ul deschide clapa de piele de la rândul tăieturii și doar până unde a ajuns lama (`trace`, `seam_row`, `peel`), cu țesut umed dedesubt. Stropii sunt mesh-uri ieftine care expiră singure și camera primește o smucitură scurtă la fiecare pas — fără `Tween` și fără `GPUParticles3D`, conform convenției.
- Promptul de interacțiune afișează numărul real de pași și aceleași cinci trepte de dificultate ca panoul. Adăugate 8 chei RO/EN noi pentru trasare; ordinea cheilor existente a fost restaurată după ce o rescriere a fișierului le sortase accidental.

Verificări rulate local:

- Suita de jupuire rescrisă pentru noul model: **188 verificări, 0 eșecuri**. Inciziile sunt conduse prin eșantioane reale de lamă pe `_accept_input`, nu prin API intern. Acoperă geometria determinista, trasarea curată/neglijentă, ridicarea cuțitului, scara uzură→stele→preț→vânzare, întreruperile, proprietatea co-op, bugetul de cadavre și drumul complet prin panoul și cuțitul reale.
- Runner headless complet: **628 verificări, 0 eșecuri**, raport `tests/results/headless_20261006_115336_3f3801`, nouă suite, fără erori.
- ENet Forest: **208 verificări, 0 eșecuri**, raport `tests/results/run_20261006_115438_ff74ad`; Swamp: **208 verificări, 0 eșecuri**, raport `tests/results/run_20261006_115531_774472`. Ambele au host 54 / client1 50 / client2 47 / client3 54 / extra 3, cu logurile de eroare curate. `client1` trage efectiv lama pe curbă prin rețea reală și primește `rabbit_pelt__s5`. Ca și înainte, codul de ieșire al scriptului nu este de încredere; rapoartele JSON și logurile sunt baza afirmației.
- Preview grafic: cele cinci capturi în `outputs/`, 32 de cadre de animație în `work/harvest-animation-frames`, `HARVEST_PREVIEW_DONE carcass=25 quality_loot=["deer_pelt__s5"]`, exit 0.
- Rulări intermediare au expus trei probleme reale, corectate înainte de rulările finale de mai sus și neincluse în totaluri: un `Control` care se ascundea în propriul callback de desen nu mai redevenea vizibil, deci banda de ritm dispărea definitiv după prima etapă trasată; panoul mai înalt acoperea complet planul apropiat 3D; iar un client putea inunda hostul cu eșantioane de lamă sau teleporta lama la capătul liniei ca să termine mai repede — avansul este acum plafonat de `speed_limit*delta`, cu două verificări dedicate.
- Nu s-a făcut commit/push.

Limite: nu există compensare de latență — hostul punctează eșantionul la primire, deci pe conexiuni proaste trasarea poate părea mai grea; WAN/latența mare rămân nevalidate. Co-op-ul nu are rol de ajutor la jupuire, conform deciziei utilizatorului. Zona de tăiere este o suprafață de lucru abstractă, nu geometria reală a animalului, deci nu există simulare anatomică. Economia persistentă, Steam și host migration rămân neimplementate.

### Jupuire arcade fără ținut click — 6 octombrie 2026 (sesiune Claude Code desktop)

Cerere: utilizatorului nu-i place ținutul click-ului la jupuire; vrea o mecanică amuzantă, diferită pe fiecare animal și din ce în ce mai grea.

Trasarea ținând click și banda de ritm au fost înlocuite cu o rutină arcade în trei mișcări, fără nimic ținut apăsat: **tăieturi-fulger** peste cusături (viteza decide: încet = plutește, rapid = taie, centrul auriu = perfect, combo), **răzuirea grăsimii** contra cronometru (mistreț, urs) și **smulgerea** tip praștie (click pe inel, întinde, click în zona verde; BOING / prea tare / rupt). Fiecare specie are un truc (`harvest_quirks` în `.tres`): căpușe (căprioară), piele groasă + grăsime (mistreț), spasme (lup), albine + grăsime (urs), alunecoasă (broască), carapace (țestoasă), se zvârcolește (șarpe), fălci + piele groasă (crocodil), fălci + piele groasă + spasme (crocodil străvechi). Detalii complete în `docs/harvesting.md`.

- `data/harvest_pattern.gd` rescris: geometrie deterministă pentru cusături, căpușe, albine, spasme, fălci, grăsime și clapă; `plan`/`move_of` împart pașii în mișcări.
- `data/definitions/animal_definition.gd`: `harvest_quirks`, `harvest_difficulty()` și `harvest_tuning()` (toate reglajele dintr-o singură dificultate + presiunea existentă); `harvest_trace` eliminat.
- `core/network_session.gd`: host-ul judecă eșantioanele de lamă (`blade` + ceasul expeditorului `bt`) și click-urile (`harvest_click`, înlocuiește `harvest_stroke`); pericolele cu ceas (fălci, grăsimea care se întărește) în `_tick_harvest_move`. Starea trimisă e compactată pe mișcare, sub un MTU (o primă variantă de 1396 B depășea MTU-ul 1392 — avertisment ENet observat și corectat).
- `ui/harvest/harvest_panel.gd` rescris (urma cuțitului, popup-uri, combo, gângănii, fălci, praștie, sunete procedurale); `actors/hunter/harvest_tool.gd` adaptat (cuțitul se apasă doar când taie, tăieturi pe piele 3D, mâna trage clapa); `game/main.gd` semnal `click_requested`; `actors/hunter/hunter.gd` trimite `bt` în loc de `blade_down`.
- Localizare RO/EN: chei noi pentru mișcări, trucuri, indicii, popup-uri și feedback; cheile vechi de trasare/ritm eliminate.
- Teste: `tests/harvest_bot.gd` (nou) joacă rutina prin API-ul real; `verify_harvest.gd` rescris (223 verificări: geometrie, fiecare truc, praștie, uzură→stele→preț, întreruperi, co-op, panou și cuțit reale, mărimea stării), `verify_swamp.gd`, `network_peer.gd`, `preview_harvest.gd` portate.

Verificări rulate local (Godot 4.7.2 console din Downloads):

- `run_headless_tests.ps1`: **663 verificări, 0 eșecuri**, nouă suite (harvest 223, swamp 52), raport `tests/results/headless_20261006_123905_a4cca9`, exit 0.
- `run_network_tests.ps1 -Map forest`: host 54 / client1 50 / client2 47 / client3 54 / extra 3, **0 eșecuri**, `host_err.log` și `client1_err.log` goale după compactarea stării; raport `tests/results/run_20261006_123815_c41448`. Codul de ieșire 1 al scriptului este problema veche documentată mai sus. Swamp prin rețea nu a fost rerulat.
- Preview grafic pe urs (`-- --animal=bear`): capturi tăieturi/răzuire/smulgere/calitate inspectate vizual; o eroare de triangulare a clapei în poziție degenerată a fost corectată după.
- Nu s-a făcut commit/push. Cealaltă sesiune Claude din CMD avea modificări necomise în același repo; nu au fost atinse în afara fișierelor de mai sus.

Limite: fără compensare de latență (albinele/cusăturile mobile pot părea decalate pe conexiuni proaste); WAN nevalidat; balansul valorilor (uzuri, viteze) e o primă trecere, nejucată de oameni.
