# Decizii confirmate

- PC, co-op online cu patru persoane: un host și trei prieteni; Steam API se adaugă ulterior.
- Progresie de vânătoare, animale mici și arme proaste → animale puternice și arme OP, în mai mulți biomi.
- Third-person, aim cu apropierea camerei.
- Lobby nocturn: foc exagerat, iluminare cozy, tarabe camo, jeep și corturi.
- Trei tarabe: arme, ghiozdane, vânzare loot. Banii și ghiozdanul sunt individuale.
- Joc bilingv English / Română, cu selector în meniu.
- Iepure → căprioară → mistreț → lup → urs; modele texturate și animații cu proporții naturale.
- Iepurele și căprioara fug; ultimele trei pot ataca. Ponderi de spawn descrescătoare.
- Jeep cu patru locuri și portbagaj comun, fiecare vânător păstrând banii propriei prăzi.

Valori provizorii pentru etapa 04: hartă 1200 × 1200 m; populație inițială 24 / plafon 40;
spawn la 8 s; ponderi 48 / 27 / 14 / 8 / 3; portbagaj 120 spații; viteză jeep 24 m/s;
100 viață per hunter, revenire în tabără după 8 s. Se pot regla după prima partidă.


## Etapa 05 — alegeri confirmate

- Arme exagerate și amuzante, care devin tot mai OP.
- Damage, cadență și capacitate îmbunătățite separat.
- Magazin cu un model central rotativ și săgeți stânga/dreapta, atât pentru arme cât și pentru ghiozdane.
- Toți pot pregăti echipamentul în lobby. Hostul dă Start pentru acces la pădure.

Valori provizorii: șase arme, trei niveluri pe ramură, prețuri 0/90/220/600/1200/2800,
rezervă de cartușe nelimitată și reîncărcare cu R. Reset-ul de test în tabără folosește T.
Progresul este păstrat la reconectare în sesiunea vie a hostului; salvarea pe disc rămâne pentru etapa următoare.

## Etapa 06 — lobby separat și jeep fizic

- Lobby-ul trebuie separat de lumi, cu loading screen comun înainte de joc.
- Mașina trebuie să poată fi condusă și să apară lângă echipă; fizica trebuie refăcută.
- Implementare: scene separate, loading cu confirmări de la toți participanții, RigidBody3D/Jolt cu patru suspensii.
- Presupunere folosită în lipsa răspunsului la întrebarea despre numărul minim: hostul poate porni cu 1–4 participanți conectați; se așteaptă încărcarea tuturor acestora. `NetworkSession.required_players=1`; pentru obligativitatea unei echipe complete se poate seta 4.
- Întoarcerea la lobby este comandată de host, prin același loading. Prada de pe sol nu este transportată, dar ghiozdanele și portbagajul sunt.
- Valori de condus provizorii: 22 m/s înainte, 7 m/s în marșarier, masă de bază 1250 kg.

## Etapa 07 — alegeri confirmate

- E la foc deschide meniul hărților; numai Forest disponibilă; hostul pornește expediția.
- Carnivorele vin să atace în loc să fugă. Mistrețul păstrează și el comportamentul agresiv.
- Hunter-ul doborât rămâne întins pe jos; numai alt player îl poate ridica.
- Alegerea explicită: ține E câteva secunde, revive gratuit, fără obiect necesar.
- Valori inițiale alese: 3 s, 50 hp la ridicare, rază de 3 m pe host.
- Auto-respawn-ul după 8 s din etapa 04 este eliminat. HP persistă la travel și reconnect.
- First person sau third person din meniu; RMB în first person apropie și aliniază arma.
- Pistol: două puncte în spate și post în față; ținta HUD ascunsă în ADS. Old rifle: lunetă cu zoom și reticul.


## Etapa 09 — Mlaștină

La cererea utilizatorului, harta 2 este o mlaștină complet integrată în expediții. Întrebările opționale despre atmosferă/faună au rămas fără răspuns în timpul implementării; am folosit atmosferă cinematică cu ceață, apă și vegetație, plus broască → țestoasă → șarpe → crocodil → crocodil uriaș. Sursele externe sunt gratuite CC0. Nu au fost cumpărate pachete și nu a fost introdus Steam API. Modelele native ale speciilor mici rămân o bază jucabilă pentru viitorul polish realist.

## Camionul pe jos, hărți mari, boși, HUD nou

La cererea utilizatorului (6 octombrie 2026):
- NPC-urile de pe camion au fost scoase de tot; magazinele și depozitul funcționează fără vânzători.
- Pe terasă nu se mai stă la posturi fixe: cine e pe camion merge liber și e purtat de el în mers. Volanul e singurul loc. Scările sunt cu E; urcarea/coborârea de pe sol cere camionul aproape oprit, ca să nu se poată sări dintr-un camion în viteză.
- Hărțile cresc de la 1200 × 1200 m la 2400 × 2400 m, cu aceeași densitate de copaci și dealuri la margine.
- Câte un boss pe hartă (Ursul Străvechi, Crocodilul Albinos de Apă Sărată), spawn aleatoriu departe de echipă, maximum doi deodată, trofee multiple și scumpe. Valori alese: 2 800 / 3 400 HP, lovitură în arie 42 / 48, 6 / 7 trofee (2 820 / 3 400 monede) plus blana (1 400 / 1 800 de bază).
- Minimap rotit după cameră, cu relief, și hartă mare (M) cu pictogramă pe specie și coroană pe boși. HUD minimal, desenat în cod, cu comenzi care dispar singure.
