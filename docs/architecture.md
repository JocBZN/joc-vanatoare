# Arhitectură — etapa 09

Godot 4.7.2, GDScript, PC, Forward+ / Vulkan implicit. Un host autoritar și maximum trei clienți.
Toate RPC-urile au aceeași cale stabilă: `/root/NetworkSession`.

| Modul | Responsabilitate |
| --- | --- |
| NetworkSession, autoload | ENet, înregistrare, roster, validare comenzi, faza lobby/loading/hunt, spawn, damage, muniție, tranzacții, loot, portbagaj, reconectare |
| LocaleSettings, autoload | Traduceri EN/RO, volum, efecte, perspectivă și calitate Low/Medium/High și calitate Low/Medium/High și calitate Low/Medium/High și identitate anonimă per profil |
| Main | Compune lumea, leagă HUD-ul desenat (`ui/hud/hud_view.gd`) și minimapul de hunter-ul local și controlează ferestrele |
| Hunter / CameraRig | Mișcare simulată de host, predicție locală, interpolare pentru ceilalți, aim și echipament |
| HunterCombat | Intenția de tragere; prezentarea sunetului, flash-ului, tracerelor și hit marker-ului |
| HunterInventory | Portofel și ghiozdan individuale, capacitate, vânzare, arme deținute, trei ramuri de upgrade și încărcătoare; serializare prin ID-uri |
| WorldCatalog / SwampMap | Expediții Forest și Swamp; seed 28641 pentru mlaștină, habitat uscat/acvatic, noroi, streaming și apă |
| GameArt / art shaders | Scan-uri CC0, PBR, cache de mesh/materiale, impostors, vânt, apă și suprafețe |
| ForestMap | Seed comun 10337, teren de 2400 m dintr-o grilă indexată (grila `heights` rămâne pentru minimap), dealuri la margine, drum, MultiMesh pe sectoare și coliziuni locale pentru trunchiuri, căutate în găleți de 32 m |
| WildlifeAnimal / AnimalCatalog | Definiții de specie, alegeri ponderate, AI numai pe host, animații și nume locale; boșii (`BOSSES`, `boss_dress.gd`), lovitura lor în arie și trofeele. Detalii: [bosses.md](bosses.md) |
| WorldRouter / LoadingScreen | Scene separate, încărcare threaded și teren construit în etape, progres real, interfață EN/RO |
| HuntingJeep | RigidBody3D cu Jolt, patru suspensii raycast, forțe de tracțiune/frânare și replicare a transformării |
| EquipmentPreview | SubViewport cu World3D propriu, lumină, cameră, model normalizat, rotire cu mouse-ul și zoom |
| ShopUI / CampMenu | Carousel 3D, upgrade-uri, portbagaj cu proprietari, debara personală, setări, host/join/leave; MapMenu pornește expediția la foc sau de la volan |
| HuntingJeep („Stejarul Călător”) / ShopCounter | Camionul-bază: cabină + trunchi cu magazine, căsuță cu depozit și atelier, terasă; un singur loc (volanul), ceilalți merg pe jos pe camion și sunt purtați de el (`Hunter._carry`); scări validate de host; ghișee validate prin `_at_stall`. Detalii: [base.md](base.md) |
| HudView / Minimap | HUD desenat în cod (viață, armă sau vitezometru, bara de boss, notificări, prompt, comenzi) și minimapul cu relief, rotit după cameră, plus harta mare cu pictograme. Detalii: [hud.md](hud.md) |

```text
Main
├── WorldRoot / WorldRouter: o singură hartă activă
│   ├── Lobby / Camp: foc, corturi, tarabe și decor nocturn
│   └── ForestWorld / Forest: mediu de zi, teren, arbori și vegetație
├── Players / Peer<ID>: Hunter, Inventory, Combat, cameră
├── Wildlife: animale create de host, replici pe clienți
├── Loot: pickup-uri create și șterse de host
├── HuntingJeep: model, coliziuni, faruri, cameră și interacțiuni
├── Cinematic / HUD: HudView, Crosshair, Minimap
└── ShopUI / CampMenu / MapMenu / LoadingScreen
```

## Autoritate și transport

Clienții trimit direcție, aim, jump și input de condus la 20 Hz.
Hostul limitează vectorii, refuză valori nefinite și secvențe vechi și oprește input-ul expirat după 500 ms.
Pozițiile hunter-ilor și jeep-ului sunt transmise la aproximativ 20 Hz, comprimate cu DEFLATE.
Fauna se transmite în loturi de maximum șase animale, cu secvențe care resping actualizările mai vechi.
Roster-ul are secvență și refuză snapshot-uri anterioare mesajului Welcome; avatarul local nu poate dispărea dintr-un roster vechi.
Roster și jeep folosesc canalul 1; input-ul canalul 2; fauna canalul 3.
Comenzile economice, loot-ul, inventarul privat și focurile folosesc canalul fiabil 0.
Relay între clienți este dezactivat: comunicarea de joc trece prin host.

Clientul transmite originea și direcția aim-ului. Hostul verifică distanța față de hunter,
cooldown-ul calculat din upgrade, cartușele, reîncărcarea, starea de viață și locul din jeep; calculează raza camerei și razele de la țeavă.
Numai hostul aplică damage, alege dispersia și acordă materialul recoltat manual. Clienții primesc efectele focului.
Obiecte / Resources nu sunt deserializate din RPC-uri; conținutul este selectat prin ID-uri din catalog.

Hostul verifică proximitatea tarabei sau pickup-ului și fondurile / spațiul înainte de tranzacție.
Pickup-ul dispare numai după colectare reușită. Dublarea unei cereri nu repetă plata.
Inventarul complet este trimis numai proprietarului; echipamentul vizibil ajunge la toți.

## Proprietate și reconectare

Portbagajul conține `{kind, owner}`; `owner` este identitatea stabilă a profilului,
independentă de ID-ul ENet care se schimbă la reconectare.
Clienții văd numele proprietarului și flag-ul `mine`, fără identitățile celorlalți.
Hostul păstrează inventarul unui peer deconectat și îi eliberează locul din jeep.
Retragerea și vânzarea filtrează obiectele după proprietar.
Identitatea actuală este anonimă, pentru prototip; conturile Steam verificate se leagă în etapa de integrare.

## Lume și animații

Terenul și pozițiile copacilor sunt deterministe, identice pe fiecare peer.
Trunchiurile au coliziuni în raza de 75 m de observatori; vizualurile se grupează pe sectoare de 64 m.
Hostul generează animale la 55–145 m de exploratori, cu maximum 40 animale vii.
Speciile mai puternice au ponderi mai mici. Moartea lasă un cadavru fără recompensă automată.
Fiecare cadavru trebuie recoltat prin tăieturi manuale validate de host; progresul și greșelile rămân pe animal la întrerupere.
Cadavrele nerecoltate expiră după 10 minute fără lucru activ, cu un buget de 80 cadavre neocupate; recoltele finalizate eliberează entitatea.
Calitatea este parte din ID-ul validat al materialului și persistă în inventar, portbagaj și reconectare. Detalii: [Recoltare manuală](harvesting.md).

Animațiile Idle / Walk / Run / Attack / Die sunt selectate după starea hostului și redate pe fiecare client.
Unde sursa nu conține un clip separat, se folosesc clipuri adaptate sau stări derivate:
căprioara folosește Run încetinit pentru Walk; mistrețul Walk accelerat pentru Run;
mistrețul are Idle / Die procedurale, iar ursul are rig și cicluri adăugate proiectului.

Documentație: [Godot multiplayer](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html),
[SceneMultiplayer](https://docs.godotengine.org/en/4.7/classes/class_scenemultiplayer.html).

## Lobby și progresie

`NetworkSession.phase` începe cu `lobby`. Nu există spawn automat înainte de Start.
Hunter-ul și jeep-ul sunt limitați la tabără pe host; predicția locală aplică aceeași limită.
Numai peer-ul 1 poate comanda `start_hunt`, `return_lobby` și `cancel_loading`.
Faza și ID-ul hărții intră în Welcome și snapshot-uri; un client intrat ulterior încarcă harta activă înainte să joace.

`WeaponDefinition` include preț, damage, cooldown, automat, capacitate, reîncărcare și baza prețului de upgrade.
`HunterInventory` ține `owned_weapons`, `weapon_upgrades`, `magazines`, `reload_remaining`.
Comenzile `buy_weapon`, `upgrade`, `equip`, `reload` sunt validate central.
Statistica armei se calculează din definiție și niveluri; clientul nu trimite damage sau preț.
Hostul consumă cartușul înainte de aplicarea focului și finalizează reîncărcarea din timpul simulat.
Snapshot-ul public include echipamentul activ, nivelurile lui, muniția și reîncărcarea;
colecția completă de arme, portofelul și loot-ul sunt trimise numai proprietarului.

`ShopUI` păstrează selecția pe durata unei cumpărări sau schimbări de limbă.
`EquipmentPreview` nu conține animale, inventare sau collidere de gameplay.
Preview-ul se oprește când magazinul se închide; modelul anterior este eliberat când schimbi obiectul.
Lada veche de test rămâne decorativă, fără interacțiune economică.

## Tranziții și încărcare

Scena Main, căile Players, inventarele, NetworkSession și jeep-ul persistă. WorldRouter înlocuiește numai decorul.
Lobby și ForestWorld sunt scene native independente; tarabele și focul nu sunt instanțiate în pădure.
ForestWorld construiește terenul și vegetația în loturi care cedează cadrul, apoi preîncarcă cele cinci modele de animale.
LoadingScreen folosește progresul ResourceLoader și al construcției terenului, fără cronometru care simulează progresul.

La Start, hostul crește `world_epoch`, transmite harta și lista participanților pe canalul fiabil 0, apoi blochează simularea.
Fiecare peer confirmă epoch-ul după încărcare. Hostul face commit numai după toate confirmările și înregistrările în curs.
Commit poziționează vânătorii și jeep-ul în aceeași poiană, activează fizica și creează fauna.
Un peer deconectat este eliminat din barieră; un peer înregistrat în timpul loading-ului este adăugat.
Un client intrat ulterior în expediție încarcă numai propria hartă, apoi apare lângă jeep, fără a opri echipa.
Snapshot-urile, fauna și mesajele de loot includ epoch-ul pentru a refuza date de pe o hartă veche.
Anularea invalidează job-ul WorldRouter. Un loading nereușit sau expirat după 45 s readuce expediția în lobby.
Inventarele și portbagajul persistă; animalele și loot-ul rămas pe sol sunt eliminate la schimbarea hărții.

## Fizica jeep-ului

Doar hostul aplică forțe în `_integrate_forces`; clienții interpolează poziția și quaternion-ul unui corp înghețat.
Patru raycast-uri caută solul pe layer World. Arcurile și amortizoarele aplică forțe la punctele roților;
tracțiunea longitudinală și laterală sunt limitate printr-un cerc de frecare, în funcție de încărcarea roții.
Roțile fără sol nu aplică forță de motor. Centrul de masă este jos, iar virajul se reduce cu viteza.
Frâna compensează și componenta gravitației pe pantă. Comenzile expirate după 500 ms activează frâna;
un jeep fără șofer rămâne parcat. Masa de bază este 1250 kg, plus 85 kg/pasager și 2 kg/spațiu de pradă.
Caroseria are collidere separate de model și continuous collision detection.
Resetarea la schimbarea hărții și redresarea sunt teleportări explicite; condusul normal este calculat prin forțe.
Orbit-ul camerei urmărește poziția, fără pitch/roll-ul caroseriei. Roțile vizuale urmează suspensia și direcția.

Referințe: [RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html),
[PhysicsDirectBodyState3D](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectbodystate3d.html),
[ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html).

## Etapa 07: harta la foc și urmărirea animalelor

Camp/GiantCampfire/Expedition este un LobbyInteractable cu rază de 4,8 m.
E deschide MapMenu EN/RO, numai Forest; Main eliberează mouse-ul și blochează input-ul de gameplay.
Esc sau Înapoi redă controlul. Start este dezactivat la client și eliminat din meniul Esc în lobby.
Hostul trimite `start_hunt("forest")`; serverul validează harta, starea hunter-ului și proximitatea focului.
Start continuă prin WorldRouter și bariera comună. Înapoi în tabără rămâne în meniul Esc al hostului.
Imaginea selectorului este o randare a pădurii reale fără HUD.

WildlifeAnimal păstrează target_peer și alert_clock. Agresivele urmăresc și nu intră în fuga pasivă.
take_damage primește ID-ul shooter-ului verificat de host și provoacă urmărirea lui.
Țintele trebuie să fie vii, pe jos și încărcate. Animalul se oprește în apropiere și atacă la interval de 1,5 s.
Lup: detectare 45 m, alergare 9 m/s; urs: 38 m / 7 m/s; mistreț: 17 m / 6 m/s.
Memorie 30 s, urmărire până la 125 m. Sonde scurte ocolesc trunchiurile; fără navmesh global.
Iepurele și căprioara păstrează fuga, inclusiv 8 s după damage. AI și damage rulează numai pe host.

## Etapa 07: hunter doborât și revive

La hp=0 Hunter rotește modelul și capsula orizontal, coboară numele și ascunde arma.
Gravitația așază corpul pe teren. Snapshot-ul transmite hp, yaw, revive_progress și revive_helper;
clienții reconstruiesc poziția, orientarea și statusul. Timer-ul vechi de auto-respawn este eliminat.
ReviveInteraction expune corpul celorlalți, cu Hold E și procent. sample_input transmite ținta cât timp E este ținut;
mișcarea, săritura, aim-ul și focul se opresc. _tick_revives verifică viețile, harta, distanța de maximum 3 m
și linia de vizibilitate, inclusiv coliziunile jeep-ului. Un singur helper avansează fiecare țintă.
Release, distanța și input-ul expirat anulează job-ul; damage_version schimbat la helper resetează progresul.
După 3 s simulate, hostul aplică 50 hp fără să schimbe inventarul sau monedele și publică statusul.
Input-ul local încă ținut nu expiră din cauza unui hitch de randare; timeout-ul remote rămâne 300 ms.
Tranzițiile anulează job-urile, dar păstrează hp. health_profiles păstrează hp la reconnect în sesiunea hostului.
Nu există self-revive, auto-heal sau salvarea vieții între sesiuni.

## Etapa 07: perspective și ADS

LocaleSettings salvează perspective=first/third; CampMenu expune alegerea EN/RO în meniul inițial și Esc.
CameraRig pune camera la y=1,62 m, fără distanță SpringArm, ascunzând numai corpul hunter-ului local în first person.
FirstPersonWeapon creează un viewmodel local din arma echipată, cu mâini, lumină și trei puncte de cătare fizice.
ADS centrează arma și aliniază înălțimea cătării cu raza camerei; Main ascunde ținta HUD.
WeaponDefinition selectează sight_type și ads_fov: Old rifle scope / 24°, celelalte iron / 62°.
ScopeOverlay folosește lumea mărită prin camera reală, cercul opac și reticulul, sub HUD. Viewmodel-ul se ascunde.
Recoil-ul și reîncărcarea urmăresc Combat / Inventory. Input-ul include first, yaw și pitch.
Hostul reconstruiește muzzle-ul unui client în first person și păstrează verificarea liniei de tragere,
a muniției și a cooldown-ului. Snapshot-urile păstrează pitch și aim pentru ceilalți jucători.
La doborâre și în jeep camera este externă; preferința rămâne salvată pentru revenirea pe jos.


Etapa 09: WorldRouter acceptă lobby/forest/swamp. Fauna se alege per map_id, iar NetworkSession folosește WorldCatalog.is_hunt pentru timeout, acknowledgements, populate și replicare. Căile Players/Wildlife/Loot/Jeep și RPC-urile rămân stabile la schimbarea scenei. Referința internă NetworkSession.forest poate indica ForestMap sau SwampMap (subclasă), pentru compatibilitate cu sistemele de loot, spawn și vehicul. Mlaștina are scene proprii și nu adaugă scenery în lobby.

Etapa Stejarul Călător: jeep-ul și tarabele au fost înlocuite de un singur vehicul-bază. `HuntingJeep` (același API: `enter`, `exit_seat`, `occupants`, `reset_state`, `recover`, snapshot) e acum un camion cu remorcă-trunchi, construit de `actors/vehicles/oak_truck_model.gd`. Locul 0 e volanul, locurile 1–3 sunt posturi de tragere pe terasă; `_shoot` acceptă locurile > 0 și refuză șoferul. Fără șofer, camionul se îngheață pe host (`parked`, replicat) și își coboară rampa, ca să se poată merge pe verandă și în căsuță. Când pornește, cei rămași pe el urcă automat pe posturi (`secure_riders`). `start_hunt` se acceptă de la volan sau lângă foc, iar locurile ocupate se păstrează prin călătorie (`travel_seats`). Camionul nu are layer-ul Hunters în mask. Tabăra e doar focul, cu decor cozy (`world/camp/cozy_camp.gd`). Debaraua (`HunterInventory.stored`) și mașina de curățat sunt în căsuță; curățarea merge și în expediție. Detalii: [base.md](base.md).

Etapa „pe jos pe camion, hărți mari, boși, HUD nou”: NPC-urile au fost scoase (`actors/npc/`, `data/npc_catalog.gd`, citatul din magazin). Camionul are un singur loc, volanul (`SEATS`/`occupants` de lungime 1); posturile de pe terasă și `secure_riders` nu mai există. Cine stă pe camion e purtat de el: `Hunter._carry()` reaplică transformarea camionului de la cadrul trecut la cel curent înainte de mișcarea proprie, platforma încorporată e oprită pentru layer-ul 16, replica de pe client rulează înaintea vânătorilor (`process_physics_priority = -10`), iar snapshot-ul are poziția și orientarea locale (`lp`, `ly`), folosite la interpolare și la reconciliere în spațiul camionului. Acțiunea nouă `climb` (board/alight/ladder_up/ladder_down) mută hunterul pe scări, validată de host; `place_aboard()` păstrează lanțul de transport. Călătoria păstrează șoferul și pozițiile locale ale celor de pe camion (`travel_driver`, `travel_riders`). Hărțile au 2,4 km (`ForestMap.SIZE/LIMIT`), cu teren din grilă indexată. Boșii (`AnimalCatalog.BOSSES`) apar pe ceasul `boss_clock`, maximum doi deodată, și lasă trofee la moarte (`boss_defeated`). HUD-ul vechi din `main.tscn` a fost înlocuit de `ui/hud/hud_view.gd`, iar minimapul de un radar cu relief din `heights` (shader) și o hartă mare cu pictograme. Nu există RPC-uri noi; `climb` trece prin `_action`. Detalii: [base.md](base.md), [bosses.md](bosses.md), [hud.md](hud.md).
