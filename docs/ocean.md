# Oceanul, camionul-barcă și costumele de scufundare

## Upgrade-urile Stejarului Călător

Banca de tuning (garajul) e pe flancul drept al camionului, în fața trapei de portbagaj. Se deschide cu **E**. Upgrade-urile sunt ale camionului, deci ale tuturor. Plătește cine cumpără, din portofelul lui. Nivelurile stau pe host (`NetworkSession.truck_state`) și ajung la ceilalți prin snapshot-ul camionului (`up`), deci un client care intră mai târziu vede camionul complet.

| Upgrade | Niveluri | Preț | Efect |
| --- | --- | --- | --- |
| Viteză maximă | 3 | 600 / 1400 / 3000 | viteza maximă ×1,16 / ×1,34 / ×1,55 (19 → 29,5 m/s) |
| Accelerație | 3 | 500 / 1200 / 2600 | forța motorului ×1,3 / ×1,65 / ×2,1 |
| Plug de bivol | 1 | 900 | bară de fier cu coarne în față; animalele lovite la peste 5 m/s primesc 7 daune pe m/s (un animal e lovit cel mult o dată la 0,8 s) |
| Turn de pază | 1 (cere plugul) | 1800 | turn înalt pe terasă cu reflector; scara cu **E** duce pe platformă (12,4 m); cutia de „călărit” a camionului crește |
| Rachete nitro | 1 (cere turnul) | 3200 | **Shift** în timp ce accelerezi: ×2,4 forță și ×1,45 viteză maximă timp de 3,2 s; rezervorul se reîncarcă în 9 s; flăcări și indicator pe HUD |
| Kit de barcă | 1 (cere nitro) | 5500 | pontoane, elice, cârmă: camionul plutește și navighează pe orice apă; deschide Oceanul |

Pentru testare, în jocul pornit cu fereastră (nu în teste headless) upgrade-urile costă 0 (`TruckUpgrades.free_for_testing`, pus de `main.gd` lângă `debug_unlock_all`).

Fișiere: `data/truck_upgrades.gd` (regulile), `actors/vehicles/truck_builds.gd` (geometria celor patru construcții), `actors/vehicles/hunting_jeep.gd` (efectele: viteză, nitro, bară, barcă, cutii de urcare), `ui/garage/garage_ui.gd` (ecranul). Cumpărarea e validată de host (`buy_truck_upgrade`): banca trebuie să fie în rază, upgrade-ul să existe, să nu fie la maxim, să fie îndeplinită cerința și să ajungă banii. Un dicționar falsificat din snapshot e curățat de `TruckUpgrades.sanitize`.

## Camionul pe apă

Cu kitul de barcă, `HuntingJeep._apply_boat_forces` (doar pe host) pune 8 puncte de plutire de-a lungul pontoanelor (pescaj 0,75 m, amortizate), o forță de elice la pupa proporțională cu motorul și cu upgrade-ul de viteză, rezistență la înaintare (liniară + pătratică, mare lateral) și o viteză de giraj urmărind volanul. Fără șofer, barca se oprește singură. Apa e plană pentru fizică; valurile sunt doar vizuale.

## Harta Ocean

Se pornește de la volan sau de la foc, **doar** cu kitul de barcă (meniul arată motivul, iar hostul refuză altfel cu `OCEAN_NEEDS_BOAT`).

- **Teren:** `world/ocean/ocean_map.gd` (`OceanMap`, extinde `ForestMap`). 2,4 × 2,4 km, determinist din sămânța trimisă de host: câmpie submarină, bancuri, canioane, 17 insule cu plaje, plus insula de tabără plată în centru (camionul pornește acolo, cu un debarcader). Țărmul lumii e un lanț de bancuri.
- **Apă:** `ocean_water.gdshader` pe un clipmap de 5 inele care urmează camera. Valuri (trei unde, constantele sunt oglindite în `OceanMap.SWELLS`), refracție, culoare după adâncime, spumă la țărm și pe creste, ondulații din pașii/mișcarea înotătorilor, fereastra lui Snell văzută de sub apă.
- **Fund:** `ocean_floor.gdshader`: nisip cu valuri, nisip ud la linia apei, plajă/iarbă/junglă, stâncă pe pante, caustice animate.
- **Flora și peisaj** (`ocean_flora.gd`, toate procedurale): corali ramificați, de creier, evantai, masă, tuburi; anemone, aricii, stele de mare, scoici-uriaș; păduri de alge care se leagănă; iarbă de mare; stânci; palmieri cu coliziune; faruri; epave (cu un cufăr care strălucește), ruine scufundate, schelet de balenă; 64 de bancuri de pești și 6 manta, desenate în shader (fără trafic de rețea).
- **Sub apă:** `ocean_world.gd` schimbă atmosfera când camera coboară sub suprafață: ceață turcoaz care se îngroașă și se întunecă cu adâncimea, soare albăstrui, zăpadă marină, gradare de culoare cu o ușoară unduire.
- **Minimap:** modul ocean în `map_relief.gdshader` (lagună turcoaz → bleumarin) și nume de locuri (`map_places`).

## Înot și costumele de scufundare

În Ocean, orice vânător poartă costumul (`art/diving_suit.gd`): neopren cu dungă de culoarea lui (4 culori), glugă, mască cu lentilă luminoasă, snorkel, două butelii pe spate, labe, centură de plumbi, lanternă de cască (se aprinde sub 6 m) și bule. Costumul se pune peste vizualul replicat și se scoate la plecare.

Înoți când apa îți trece de talie (intri la 1,05 m, ieși sub 0,55 m, deci pe mal mergi normal): `WASD` te mișcă în direcția camerei, deci te uiți în jos și te scufunzi; **Space** urcă; **Shift** dă din labe mai tare. Aproape de suprafață, stând pe loc, ieși singur cu capul din apă; mai adânc stai neutru. Postura (culcat, labele bat) e calculată pe toate peer-urile din poziția replicată. O săritură de pe punte e frânată în apă.

## Creaturile mării

Opt specii plus boss, toate agresive, înoată în 3D (`swimmer` în `AnimalDefinition`) și vânează **doar oameni aflați în apă**: pe plajă, pe debarcader sau pe camion ești în siguranță.

| Specie | Viață | Daune | Particularitate |
| --- | --- | --- | --- |
| Barracuda | 90 | 9 | rapidă, în stol (cheamă alte animale până la 55 m) |
| Mureană | 140 | 20 | stă la pândă lângă vizuină |
| Rechin de recif | 220 | 18 | stol mic, se învârte în jurul prăzii |
| Meduză-cutie | 60 | 14 | lentă, pulsează, înțeapă |
| Anghilă electrică | 160 | 22 | șoc în rază de 5,5 m asupra tuturor din apă |
| Rechin ciocan | 380 | 28 | atac fulger de la 12 m |
| Rechin alb | 520 | 36 | atac fulger de la 15 m, poate ieși din apă |
| Orcă | 900 | 44 | cea mai puternică din turmă |
| **Megalodon** (boss) | 4200 | 62 | 16 m, lovește mai mulți odată, lasă dinți, perle și o ancoră |

Ce știu să facă (`WildlifeAnimal._swim_ai`): țin cont de unde vei fi (anticipare), se învârt în cerc cât se reîncarcă atacul, lovesc într-o rafală, se retrag după mușcătură și revin, simt un împușcat și răspund la zgomot, sunt chemați de colegi, se dau înapoi din ape mici și ocolesc fundul. Cadavrele se răstoarnă și plutesc la suprafață; pot fi jupuite acolo (scafandrul rămâne suspendat în apă). Pielile se vând, iar boss-ul lasă trofee.

## Verificare

- `tests/verify_truck.gd` (38 de verificări): reguli, cumpărare, prețuri, replicare, turn, bară, nitro, poarta oceanului.
- `tests/verify_ocean.gd` (59 de verificări): conținut și texte, meniul, terenul și apa, barca (plutește, avansează, vireză, se oprește, upgrade-uri), înot și costum, populația, vânătoarea (rechin, șocul anghilei), cadavre și jupuit, minimap, boss.
- `tests/preview_truck.gd`, `tests/preview_ocean.gd`, `tests/preview_sea.gd` fac capturi reale (cer fereastră, nu merg headless).

## Limite

- Nu am jucat cu tastatură și mouse; balansul (prețuri, viteze, daune, număr de creaturi) e neverificat în joc.
- Performanța pe Intel UHD 620 nu e măsurată; încărcarea hărții durează ~9 s pe acest PC.
- Fără sunet nou pentru ocean, fără oxigen limitat, fără împingere la mușcătură.
- Modelele sunt low-poly procedurale; au fost verificate doar din capturi.
- Epavele, ruinele și scheletul nu au coliziune (poți înota prin ele).

## Actualizare: barca care se transformă, nitro stabil, apă tropicală, mai multe creaturi, Calamarul colosal

**Camionul**
- **Nitro nu mai răstoarnă camionul:** forța nitro e acum o împingere la centrul de masă (nu mai trece prin anvelope și nu le mănâncă aderența laterală), tracțiunea e limitată la ~3/4 din aderență, iar stabilizatori țin tangajul și ruliul față de teren; în aer camionul se nivelează singur. Virajul se îngustează mult peste viteza normală și centrul de masă e mai jos. Măsurat: tangaj maxim 0,0002 rad la nitro complet.
- **Construcții cu montaj logic:** plugul de bivol e fixat de șasiu cu tuburi; turnul are placă de bază și cabluri către balustradă; nitro are o bară de rachete sub șasiu și un rastel de butelii de azot cu furtunuri.
- **Barca se transformă la contactul cu apa:** pe uscat kitul stă strâns (pontoane sub șasiu, scut pe capotă, elice ridicată, catarg jos). Când un punct al carenei atinge apa, `boat_deploy` urcă de la 0 la 1 (host, replicat în snapshot, `dep`), iar `animate_boat` desface totul pe rând: pontoanele se rotesc în afară cu un mic ricoșeu, scutul se ridică, brațul cu elice coboară și catargul telescopează. Pe uscat, după ~1,2 s, se strânge la loc. Plutirea și elicea cresc cu desfacerea.

**Apa și lumina:** apă tropicală limpede (turcoaz, vizibilitate mare aproape de suprafață). Lumina scade exponențial cu adâncimea (≈1/e la 38 m): soarele, lumina ambientală, ceața, fundul, corali, alge și creaturi se întunecă, ajungând la bleumarin și apoi aproape negru; lanterna de cască ajută.

**Creaturi marine:** acum 18 specii + 2 boși. Noi periculoase: pește-spadă (atac fulger), rechin-tigru, pește-leu, pește-balon (se umflă), șarpe de mare, caravelă portugheză (înțeapă la suprafață). Noi pașnice (fug de scafandri, se jupoaie): delfin, țestoasă de mare, raia manta, biban de mare. Fiecare are model propriu și animație de înot: undă din cap în coadă, contra-balans al capului, înclinare în viraje, înotătoare care se strâng la viteză, branhii, ochi cu reflexii, fălci; delfinul/orca bat coada pe verticală; manta undulează aripa; țestoasa dă din lopeți; peștele-balon se umflă; peștele-leu își unduiește evantaiele. Pielea (`sea_skin.gdshader`) are modele pe corp (bare, pete, dungi, benzi) și sclipiri de solzi. Bancurile ambientale au 5 tipuri de pești de recif (tang, înger, clovn, sardină, fluture), 110 de bancuri.

**Calamarul colosal (al doilea boss al Oceanului):** 5200 viață, ~35 m cu tentaculele. Mantă lofted cu aripioare și fotofori luminoși, doi ochi uriași (irisul devine roșu când e furios), pâlnie, cioc cu dinți, 8 brațe cu ventuze și 2 tentacule de 14 segmente cu cluburi cu cârlige. Pielea (`squid.gdshader`) are cromatofori care clipesc și se înroșesc cu agitația. Atacuri: combo de trei lovituri de tentacule în arie (coil, bici cu undă, revenire), jet în rafală și, rănit sub 55%, fuge înapoi într-un nor de cerneală. Animații: plutire cu brațele desfăcute, vânătoare cu tentaculele întinse, jet aerodinamic, moarte moale pe spate. Cei doi boși apar la începutul hărții (nu cu trofee comune): pielea, ciocul, ochii și sacii de cerneală se vând.

Teste: `verify_ocean.gd` 75, `verify_truck.gd` 39 (include nitro la viteză maximă), plus suitele existente rulate din nou (maps_predators 42, leap 25, bosses 76, swamp 51, worlds_vehicle 45).

## Construcții absurde și Galionul

Vezi `CONTEXT_PROIECT.md` (ultima secțiune). Construcții (în ordinea garajului): Capul de Bivol, Cuibul Corbului, Rachete-Morcov, Galionul, Grătarul Spitalicesc, Aspiratorul de Pradă, Sfera de Sticlă, Gramofonul Anti-Rechini (H), Stejarul Zburător (C). Capturile se fac cu `tests/preview_builds.gd`. Harponul are +100% daune la animalele marine (`marine_bonus`).
