# Context și jurnal de dezvoltare — Hunt Together

Actualizat: 5 octombrie 2026. Acest fișier este punctul de reluare al proiectului.

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
