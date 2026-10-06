# Jupuirea — rutina arcade

Jupuirea este mecanica principală a jocului. Un animal doborât nu produce nimic
automat: rămâne cadavru până când un vânător îl lucrează, iar cât de curat îl
lucrează decide direct cât valorează blana.

Nimic nu se ține apăsat. Mouse-ul mișcă un cuțit virtual peste piele, iar
**viteza** decide tot: mișcat încet, cuțitul doar plutește (îl poți repoziționa
peste orice); mișcat rapid, taie.

## Cele trei mișcări

Apropie-te de cadavru și apasă `E`. Camera trece pe planul apropiat, apare
cuțitul Gerber LMF, iar panoul din dreapta devine tabla de joc. Fiecare animal
este o serie scurtă de pași, în ordinea:

1. **Tăieturi-fulger** (`MOVE_SLASH`) — pe piele apar 2–4 cusături. Treci rapid
   peste fiecare, ca o lovitură de sabie (gen Fruit Ninja). Trecerea prin
   segmentul auriu din centru este **PERFECT**; mai spre capete e doar „bine” și
   strică puțin blana. Tăieturile la mai puțin de 0,8 s una de alta țin un
   **COMBO** (doar cosmetic: text, sunet tot mai ascuțit). Un val de cusături
   terminat = un pas.
2. **Răzuiește grăsimea** (`MOVE_SCRAPE`, doar mistreț și urs) — bule de seu de
   frecat rapid înainte-înapoi până dispar, contra cronometru. Grăsimea rămasă la
   final se întărește și strică blana proporțional.
3. **Smulge pielea** (`MOVE_YANK`, pașii finali) — praștie: click pe inel ca să
   prinzi clapa, întinde-o pe direcția săgeții și dă click din nou în zona verde.
   Prea puțin = **BOING** (clapa sare înapoi, reîncerci), prea mult = „prea tare”,
   iar peste zona roșie pielea se **rupe** singură.

`E`, `Esc` sau `WASD` renunță oricând. Pașii terminați și stricăciunile rămân pe
cadavru; valul în curs se reia de la început.

## Trucul fiecărui animal

| Animal | Pași | Truc (`harvest_quirks`) |
|---|---|---|
| Iepure | 3 | — (tutorial) |
| Căprioară | 4 | **Căpușe** care se târăsc pe blană; tăiată, o căpușă face SPLAT |
| Mistreț | 6 | **Piele groasă** (fiecare cusătură cere 2 tăieturi) + **grăsime** |
| Lup | 8 | **Spasme**: „!” de avertizare, apoi corpul dă din picior — tăietura alunecă |
| Urs | 10 | **Albine** în blana cu miere (AU!) + **grăsime** (2 răzuiri) |
| Broască | 3 | **Alunecoasă**: toată pielea fuge încet de sub cuțit |
| Țestoasă | 4 | **Carapace**: fiecare cusătură cere 2 tăieturi |
| Șarpe | 6 | **Se zvârcolește**: cusăturile ondulează |
| Crocodil | 10 | **Reflex de mușcătură** pe o latură + piele groasă |
| Crocodil străvechi | 14 | Fălci + piele groasă + spasme |

Fălcile: o zonă roșie pe o latură; se deschid larg ca avertizare, apoi **HAP**.
Dacă lama e în zonă în momentul mușcăturii, blana are de suferit (o singură dată
pe mușcătură). Prima cusătură a fiecărui val e mereu în zona fălcilor, deci
trebuie prinsă între mușcături.

## Dificultatea

O singură valoare per specie, `harvest_difficulty()` (0 la iepure/broască, 1 la
crocodilul străvechi), derivată din `harvest_window`, plus aceeași curbă de
presiune ca înainte (crește doar cu pașii terminați, nu cu timpul sau
greșelile). `AnimalDefinition.harvest_tuning` scoate din ele tot:

- număr de cusături 2→4, lungime .42→.25, centrul perfect .48→.24 din jumătate;
- viteza minimă de tăiere .9→1.5 unități/s; de la dificultate .5 cusăturile au
  **săgeată** (taie doar în sensul ei);
- zona verde a smulgerii .34→.13, plus „tremurul” pielii (zona alunecă în timp,
  deci eliberarea devine o problemă de sincronizare, nu doar de poziție);
- grăsime 3→5 bule, timp 7.5→5 s; perioada spasmelor 3.4→2.4 s, a fălcilor 3.6→2.6 s.

## Ce strică blana

Scorul rămâne o singură valoare, **uzura** pe cadavru în miimi (0–1000):

| Eveniment | Uzură |
|---|---|
| Tăietură perfectă / bulă curățată / smulgere perfectă | 0 |
| Tăietură spre capete | 4–20 |
| Prea încet (cuțitul se agață) | 10 |
| Smulgere bună, dar nu perfectă | 10 |
| BOING | 15 |
| Pe dos (contra săgeții) | 20 |
| Căpușă | 35 |
| Grăsime întărită | până la 35 per bulă |
| Spasm | 40 |
| Albină | 45 |
| Prea tare | 55 |
| Mușcătură | 70 |
| Pielea ruptă | 110 |

## Stele și preț

Neschimbate:

| Uzură | Stele | Valoare |
|---|---|---|
| 0–60 | ★★★★★ | 150% |
| 61–220 | ★★★★☆ | 120% |
| 221–430 | ★★★☆☆ | 100% |
| 431–680 | ★★☆☆☆ | 50% |
| peste 680 | ★☆☆☆☆ | 10% |

Calitatea este bătută în `sell_value` la minare (`<loot>__s<stele>`), deci se
păstrează prin ghiozdan, portbagaj, serializare, reconectare și vânzare.

## Autoritate și date

Clientul trimite doar **poziția brută a lamei** (`blade`) și **ceasul propriu**
al eșantionului (`bt`, ms) prin fluxul normal de input, la ~20 Hz. Viteza se
măsoară pe ceasul expeditorului, ca jitter-ul de rețea să nu transforme o
tăietură rapidă într-una „prea lentă”. Click-urile merg pe canalul fiabil ca
acțiune `harvest_click` = `id:token:nr:x:y`; numărul click-ului doar crește, iar
un click la peste .5 unități de lama cunoscută e respins (nu se poate teleporta).

Host-ul regenerează singur toată geometria din `HarvestPattern` (cusături,
căpușe, albine, fălci, grăsime, clapă) din `animal_id` + pas + timpul mișcării,
și decide fiecare tăietură — clientul nu raportează niciodată un rezultat.
Starea trimisă conține doar contoarele vii și reglajele mișcării curente, ca să
rămână sub un MTU. Fiecare eveniment vizibil incrementează `fx`, iar panoul îl
afișează o singură dată.

Validările de sesiune sunt cele dinainte: token, `world_epoch`, distanța de
2.8 m, fără obstacole, `damage_version`, focus; întreruperile eliberează
cadavrul; un cadavru lucrat e protejat de expirare.

## Prezentare

- Panoul: piele cu blană/solzi, cusături cusute cu centrul auriu și săgeți,
  urmă luminoasă a cuțitului când taie, popup-uri arcade (PERFECT!, ZVÂC!, CRAC!,
  SPLAT!, AU! ALBINĂ!, HAP!, BOING!, FLOP!, RRRRUPT!), insignă de COMBO, tremurul
  tablei la spasme și lovituri, sunete procedurale (șuierat, BOING, FLOP, zumzet
  de albine, răzuire).
- 3D: cuțitul urmărește lama și se apasă în piele doar când taie; cusăturile
  acceptate apar ca tăieturi pe piele (și alunecă la broască/șarpe); mâna liberă
  trage clapa în timpul smulgerii. Fără `Tween` și `GPUParticles3D`.

## Teste

`tests/harvest_bot.gd` joacă rutina din starea replicată (perfect, neglijent sau
distructiv) și e folosit de `verify_harvest.gd`, `verify_swamp.gd`,
`network_peer.gd` și `preview_harvest.gd` (`-- --animal=bear` pentru capturi).

## Limite cunoscute

Fără compensare de latență: host-ul judecă eșantionul cu ceasul lui de mișcare,
deci pe conexiuni foarte proaste albinele și cusăturile mobile pot părea ușor
decalate. WAN-ul nu a fost validat. Un singur vânător lucrează un cadavru.
