# Jupuirea și curățarea blănii

Blana trece prin două etape, fiecare cu propriul mini-joc cu cuțitul:

1. **Pe teren** tai blana de pe animal → primești o **blană crudă**.
2. **În tabără** o bagi în **mașina de curățat blănuri** → primești blana
   curățată, la prețul întreg.

Nimic nu se ține apăsat. Mouse-ul mișcă un cuțit virtual, iar **viteza**
decide tot: mișcat încet, cuțitul doar plutește (îl poți repoziționa peste
orice); mișcat rapid, taie.

## 1. Pe teren: tăieturi-fulger

Apropie-te de cadavru și apasă `E`. Pe piele apar 2–4 cusături. Treci rapid
peste fiecare, ca o lovitură de sabie (gen Fruit Ninja). Trecerea prin segmentul
auriu din centru este **PERFECT**; mai spre capete e doar „bine” și strică puțin
blana. Tăieturile la mai puțin de 0,8 s una de alta țin un **COMBO** (cosmetic).
Un val de cusături terminat = un pas; animalele mari au mai multe valuri.

`E`, `Esc` sau `WASD` renunță oricând. Valurile terminate și stricăciunile rămân
pe cadavru; valul în curs se reia de la început.

### Trucul fiecărui animal

| Animal | Valuri | Truc (`harvest_quirks`) |
|---|---|---|
| Iepure | 2 | — (tutorial) |
| Căprioară | 3 | **Căpușe** care se târăsc pe blană; tăiată, o căpușă face SPLAT |
| Mistreț | 4 | **Piele groasă** (fiecare cusătură cere 2 tăieturi); mult seu la curățare |
| Lup | 6 | **Spasme**: „!” de avertizare, apoi corpul dă din picior — tăietura alunecă |
| Urs | 8 | **Albine** în blana cu miere (AU!); mult seu la curățare |
| Broască | 2 | **Alunecoasă**: toată pielea fuge încet de sub cuțit |
| Țestoasă | 3 | **Carapace**: fiecare cusătură cere 2 tăieturi |
| Șarpe | 4 | **Se zvârcolește**: cusăturile ondulează |
| Crocodil | 8 | **Reflex de mușcătură** pe o latură + piele groasă |
| Crocodil străvechi | 11 | Fălci + piele groasă + spasme |

Fălcile: o zonă roșie pe o latură; se deschid larg ca avertizare, apoi **HAP**.
Dacă lama e în zonă în momentul mușcăturii, blana are de suferit (o singură dată
pe mușcătură). Prima cusătură a fiecărui val e mereu în zona fălcilor.

### Dificultatea pe teren

O singură valoare per specie, `harvest_difficulty()` (0 la iepure/broască, 1 la
crocodilul străvechi), derivată din `harvest_window`, plus curba de presiune
(crește doar cu valurile terminate). `harvest_tuning` scoate din ele: 2→4
cusături, lungime .42→.25, centrul perfect .48→.24 din jumătate, viteză minimă
.9→1.5 unități/s; de la dificultate .5 cusăturile au **săgeată** (taie doar în
sensul ei); perioada spasmelor 3.4→2.4 s, a fălcilor 3.6→2.6 s.

### Ce strică blana pe teren

Uzura pe cadavru, în miimi (0–1000): tăietură spre capete 4–20, prea încet 10,
pe dos 20, căpușă 35, spasm 40, albină 45, mușcătură 70. Uzura dă stelele blănii
crude: 0–60 ★5, 61–220 ★4, 221–430 ★3, 431–680 ★2, peste 680 ★1.

## 2. În tabără: mașina de curățat blănuri

Mașina stă în tabără, lângă taraba de vânzare, cu fața spre foc. Apasă `E`
lângă ea: intră în tambur cea mai bună blană crudă din ghiozdan. Tamburul aruncă
în aer, în arcuri, tot ce e lipit de blană:

- **de tăiat:** carne, seu, scaieți (căpușe la căprioară, miere la urs, noroi la
  mistreț, alge la animalele de mlaștină) și **tendoane** (cer două tăieturi, de
  la lup în sus);
- **de ferit:** **pietre** (CLANG, cuțitul se ciobește) și **blana însăși** când
  sare din tambur (o tai = murdărie dublă).

Ce nu tai cade înapoi pe blană. **Curățenia** = 1 − murdărie/bucăți de tăiat;
sub 85% pierzi o stea, sub 60% două (niciodată sub o stea). Animalele grele aduc
mai multe bucăți (10 → 28), salve mai dese, mai multe pietre și blana care sare
mai des; mistrețul și ursul aruncă mai ales seu.

`E` / `Esc` / `WASD` oprește mașina; blana se întoarce în ghiozdan, tot crudă.

## Preț

| Stele | Curățată | Crudă (40%) |
|---|---|---|
| ★★★★★ | 150% | 60% |
| ★★★★☆ | 120% | 48% |
| ★★★☆☆ | 100% | 40% |
| ★★☆☆☆ | 50% | 20% |
| ★☆☆☆☆ | 10% | 4% |

Obiecte: blană crudă `<loot>__r<stele>`, curățată `<loot>__s<stele>`; ambele se
păstrează prin ghiozdan, portbagaj, serializare, reconectare și vânzare.

## Autoritate și date

Clientul trimite doar **poziția brută a lamei** (`blade`) și **ceasul propriu**
al eșantionului (`bt`, ms) prin fluxul normal de input, la ~20 Hz; viteza se
măsoară pe ceasul expeditorului. Host-ul regenerează toată geometria din
`HarvestPattern` (cusături, căpușe, albine, fălci) și `CleaningPattern` (salvele
tamburului) din semințe deterministe și decide fiecare tăietură. La mașină,
host-ul verifică și pozițiile de acum 0,06–0,18 s, ca un client cu latență să
nimerească ce vedea sub cuțit. Starea trimisă rămâne sub un MTU.

Jobul de curățare împrumută blana crudă din ghiozdan pe durata sesiunii:
anularea, plecarea de lângă mașină, închiderea controalelor, deconectarea sau
schimbarea hărții o pun înapoi neschimbată.

## Teste

`tests/harvest_bot.gd` joacă ambele mini-jocuri din starea replicată și e folosit
de `verify_harvest.gd`, `verify_cleaning.gd`, `verify_swamp.gd`,
`network_peer.gd` (inclusiv curățare prin rețea reală) și de `preview_harvest.gd`
/ `preview_cleaning.gd` (`-- --hide=bear_pelt__r5` pentru capturi).

## Limite cunoscute

Compensarea de latență există doar la mașină (sondare în trecut), nu și la
cusăturile mobile de pe teren. WAN-ul nu a fost validat. Un singur vânător
lucrează un cadavru; mașina o pot folosi mai mulți deodată, fiecare cu blana lui.
