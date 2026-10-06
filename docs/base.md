# Mamutul — baza-mașină din tabără

Mamutul („The Mammoth”) este baza vânătorilor: un camion-monstru absurd, low-poly, parcat la marginea de nord a taberei „din 2009”. Înlocuiește cele trei tarabe vechi de pânză. Toată geometria este procedurală (`world/camp/mega_base.gd`), în același stil toon ca restul taberei; nu folosește asset-uri externe noi.

![Mamutul văzut de la foc](base_camp.png)

## Structură

Nodul `MegaBase` este în `world/lobby/lobby.tscn`, la (0, 0, −16). În coordonatele locale, +Z privește spre foc, iar +X este capota.

| Nivel | Înălțime | Ce conține |
| --- | --- | --- |
| Sol | 0 m | Patru axe cu roți uriașe, șasiu închis (nu se intră dedesubt), ghișeul drive-through **Vânzare pradă** cu Nea Fane, între axa a doua și a patra |
| Etaj 1 · Bazar | 3,4 m | **Arsenal** (Gică Pistolică, raft cu arme OBUR), **Ghiozdane** (Tanti Rucsandra, raft cu ghiozdane), automat de băuturi gol, colț cu canapea |
| Etaj 2 · Debara | 6,8 m | Un autobuz școlar galben sudat deasupra; **Debara** (Moș Debara), rafturi cu lăzi, butoaie, frigider din '89, mașină de spălat; balcon spre schelă |
| Acoperiș · Jacuzzi | 10,2 m | Jacuzzi gonflabil cu o rață uriașă, șezlongul lui Nea Nelu (șoferul), grătar, set de terasă din plastic, antenă parabolică, catarg cu far rotativ și steag, moară de vânt, flamingo, pitic de grădină și firma neon „MAMUTUL” |
| Cabină | — | Cabină albastră, capotă, bară de protecție cromată, faruri și spot, claxoane duble, două coșuri cromate care încă fumegă |

Accesul se face pe **schela din stânga** (x −19…−15 local): rampe în zig-zag pe două benzi, cu palieri la fiecare etaj. Banda A urcă de la sol la Bazar și din nou de la palierul etajului 2 la acoperiș; banda B urcă de la Bazar la Debara. Pantele sunt 20–25°, sub limita implicită de 45° a `CharacterBody3D`. Balustradele de mijloc se opresc înaintea palierelor ca virajele să rămână libere. Intrările: Bazar și acoperiș prin spate-stânga, Debara prin balcon și ușa autobuzului.

Geometria statică este comasată pe culori într-un `MeshInstance3D` pentru fiecare culoare (`SurfaceTool.append_from`), aproximativ 60 de batch-uri. Colizioanele sunt cutii și cilindri pe layer-ul World. Mesh-urile bazei și ale NPC-urilor au meta `styled`, iar `GameArt.dress_scene` le lasă neschimbate. Doar farul, antena, moara, rața, fumul și neonul sunt animate în `_process`, local, fără trafic de rețea.

Limita taberei pentru vânători: x ±20, z de la −21 (peretele din spate al Mamutului) la 19 (`NetworkSession.LOBBY_NORTH_LIMIT`). Jeep-ul păstrează limita veche ±17. Gardurile și brazii din arcul nordic au fost scoși; două segmente noi de gard leagă gardul taberei de capetele camionului. Corturile 01/02 au fost mutate lângă foc, cu intrarea spre el.

## NPC-uri

`data/npc_catalog.gd` (`NpcCatalog`) definește echipajul și înfățișarea fiecăruia. `actors/npc/shopkeeper.gd` (`Shopkeeper`) construiește NPC-ul din primitive: corp, burtă, șorț, brațe, cap, nas, ochi, ochelari, mustață, coafură și pălărie (șapcă, beretă, căciulă, batic sau chipiu de căpitan). Animațiile sunt procedurale: respirație, gesturi când vorbește și rotirea spre vânătorul local.

| NPC | Rol | Replici |
| --- | --- | --- |
| Gică Pistolică | Arsenal (`weapons`) | 8, prima fiind „Hai să cumperi de aici în rasa ta!” |
| Tanti Rucsandra | Ghiozdane (`backpacks`) | 7 |
| Nea Fane Blănaru | Vânzare pradă (`sell`) | 7 |
| Moș Debara | Debara (`storage`) | 6 |
| Nea Nelu, Șoferul | Decor, pe acoperiș | 6 |

Replicile sunt chei `NPC_<ID>_<n>` și `NPC_<ID>_NAME` în `data/localization/{ro,en}.json`. Comportamentul este cosmetic și local pe fiecare peer: când vânătorul local intră la 9 m, NPC-ul se întoarce spre el și strigă o replică într-un balon cu fundal închis. Apoi vorbește din nou la 8–13 s, fără să repete imediat aceeași replică. La deschiderea unui magazin cu E, NPC-ul strigă o replică, iar aceeași replică apare ca citat în capul ferestrei magazinului (`ShopUI.open_for(..., quote)`).

## Ghișee și autoritate

Fiecare ghișeu este un `ShopCounter` (subclasă `LobbyInteractable`) cu `InteractionPoint` în fața tejghelei. Promptul afișează „Magazin · NPC”, iar firma și sloganul sunt pictate pe tejghea. Hostul validează în continuare fiecare tranzacție prin `_at_stall`, cu distanța 3D: un vânător de la parter nu poate cumpăra de la Arsenal, iar unul din Bazar nu ajunge la Debara. `_car_at_seller` folosește originea ghișeului de vânzare (colțul din dreapta-față al ghișeului): jeep-ul parcat la 3–4 m în dreapta nu atinge camionul.

## Debaraua (depozit personal)

- `HunterInventory.stored` reține până la `STASH_CAPACITY` = 150 spații. Este privată ca restul inventarului: o vede numai proprietarul și se serializează prin ID-uri în `export_state`/`apply_state` („stored”). De aceea rămâne la profil între expediții și la reconectare, cât timp hostul rulează. Nu există salvare între sesiuni, la fel ca pentru restul economiei.
- Acțiuni validate de host: `stash_deposit` (tot ce încape din ghiozdan), `stash_withdraw` (valoare goală = tot ce încape în ghiozdan; altfel numai ID-ul dat, de exemplu blănurile crude pentru mașina de curățat) — ambele numai la ghișeul `storage`; `sell_stash` numai la ghișeul `sell`. ID-urile necunoscute nu mută nimic. Un alt vânător nu poate goli debaraua altcuiva.
- UI: fereastra „Debara” arată ocuparea, valoarea, butoanele „Bagă tot” / „Scoate tot” și câte un rând pe tip, cu „Ia în ghiozdan”. Fereastra de vânzare are în plus „Vinde și ce ai în debara”.

## Verificare

- `tests/verify_base.gd` (în `run_headless_tests.ps1`, suita `base`): structura și echipajul, batch-urile toon, înălțimile podelelor și ale palierelor prin raycast, un vânător real (peer 2) condus prin `_accept_input` pe rampele până în Bazar, Debara și pe acoperiș, balustrada acoperișului, `_at_stall` pe etaje, limita taberei, depozitul (refuz departe de ghișeu, depunere, gradul păstrat în state, retragere pe tip, ID necunoscut, capacitate, alt vânător, vânzare o singură dată), parcarea jeep-ului la +3/+4 m de vânzător, citatul din fereastra magazinului și cheile RO/EN.
- `tests/network_peer.gd`: faza nouă `storage` — client1 depune și scoate prin ENet real la ghișeul de la etajul 2, iar hostul vede depunerea. Debaraua lui client3 supraviețuiește deconectării și reconectării.
- `tests/preview_base.gd [director]`: nouă capturi (tabără, față, lateral, Arsenal, Ghiozdane, Debara, Vânzare, acoperiș, schelă). Implicit scrie în `docs/base_*.png`.

## Limite și idei următoare

- Mamutul este staționar. Condusul lui, cu vânători pe etaje, ar cere platforme mobile replicate și o altă fizică decât jeep-ul. Este o etapă separată posibilă (de exemplu, Mamutul să apară ca bază la sosirea în expediție).
- NPC-urile nu au voce/audio; replicile sunt doar text. Nu există încă dialog interactiv dincolo de magazin.
- Camera third person se apropie în spațiile închise (autobuz, cabină), prin `SpringArm` normal.
