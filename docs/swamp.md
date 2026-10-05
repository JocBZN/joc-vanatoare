# Etapa 09 — Blackwater Marsh

Deschide project.godot în Godot 4.7.2, apoi F5. În lobby mergi la foc, apasă E, alege **Mlaștină / Swamp**, apoi **Start expedition**. Numai host-ul pornește harta. Cu server online, echipa pornește după confirmarea încărcării de către toți membrii. Fără Steam API în această etapă.

Mlaștina are 1.200 × 1.200 m, teren determinist separat, bălți puțin adânci, maluri și drum central uscat. Jeep-ul cu patru locuri sosește lângă echipă. Terenul moale încetinește vânătorii; jeep-ul are aderență și forță reduse și rezistență suplimentară în noroi. Podețele rămân ferme. Apa nu produce moarte automată și adâncimea este limitată pentru traversare. Animalele acvatice au sprijin la suprafață.

Trei puncte de explorat: colibă de pescuit abandonată (110, -155), turn vechi (-155, -100), bârlog de crocodil uriaș (170, -330). Podețele de 4,6 m au coliziune continuă pentru mașină. Un adăpost luminat marchează sosirea. Vegetația evită traseele și zonele clădirilor. Atmosferă: ceață colorată, apă turcoaz cu valuri animate, sol și lemn cu pete mari de culoare, arbori, stuf, nuferi, licurici și ambient sonor original în buclă. Materialele mediului și animalelor urmăresc direcția Stylized 3D, cu culori vii și contraste clare.

| Animal | HP | Pondere spawn | Comportament | Spațiu loot | Bani |
|---|---:|---:|---|---:|---:|
| Broască | 32 | 43 | Fuge; salturi și picioare articulate | 1 | 18 |
| Țestoasă | 85 | 28 | Fuge lent; mers articulat | 2 | 55 |
| Șarpe | 165 | 16 | Urmărește și mușcă; corp ondulat | 3 | 100 |
| Crocodil | 430 | 10 | Urmărește pe uscat și în apă; mușcă | 5 | 220 |
| Crocodil uriaș | 950 | 3 | Variantă mare, agresivă; bârlog dedicat | 8 | 550 |

Ponderile însumează 100. Populația inițială include fiecare specie și un gardian în bârlog; următoarele apariții sunt ponderate. Host-ul creează și simulează fauna, validează damage-ul, colectarea și vânzarea. Clienții primesc poziții, stări, animații, viață și nume traduse. Gardianul bârlogului rămâne prezent cât timp jucătorii explorează alte zone; alte animale îndepărtate pot fi reciclate. Limita de populație rămâne 40.

Banii, ghiozdanul și dreptul la loot sunt individuale. Portbagajul este comun cu proprietar pentru fiecare obiect. Întoarcerea la lobby păstrează cargo-ul. Revive-ul cu E ținut trei secunde, perspectiva first/third person, armele, scope-ul și upgrade-urile funcționează și aici.

## Fișiere și extindere

`data/world_catalog.gd` înregistrează expedițiile. `WorldRouter` încarcă scenele, iar `SwampMap` păstrează contractul de teren/streaming al ForestMap cu alt seed, altă înălțime și vegetație. `data/animal_catalog.gd` selectează fauna după hartă. Resursele `.tres` definesc progresia. Scenele din `actors/animals/models/` instanțiază modele GLB cu mesh-uri deformate de schelet și AnimationPlayer; broasca, țestoasa și șarpele folosesc `assets/animals/stylized/{frog,turtle,snake}.glb`. Aceste scene nu mai construiesc animale din sfere și capsule prin `swamp_animal_model.gd`.

## Modele și animații — 5 octombrie 2026

Modelele de [broască](https://opengameart.org/content/frog-low-poly-animated-3d-model) și [șarpe](https://opengameart.org/content/snake-low-poly-animated-3d-model) sunt create de methodical pixel, iar [țestoasa](https://opengameart.org/content/turtle-0) de Heathal, sub CC0. Rig-urile originale au 15, 18 și respectiv 19 oase; mesh-urile păstrează UV-urile și texturile, cu normale netezite. Dimensiunile vizuale sunt adaptate coliziunilor existente, baza este la Y=0, iar direcția frontală este −Z. Crocodilii folosesc același model CC0 Micket, cu rig-ul și secvențele create în proiect; varianta uriașă are o scară mai mare.

| Specie | Clipuri provenite din asset-ul original | Secvențe suplimentare create în proiect |
| --- | --- | --- |
| Broască | `Idle`, `Walk`, `Jump`, `Land`; `Run` combină saltul și aterizarea originale | `Die`: așezarea corpului și relaxarea membrelor |
| Șarpe | `Idle`, `Walk`, cu ondulare articulată a coloanei | `Attack`: ridicare și fandare a capului; `Die`: așezarea coloanei |
| Țestoasă | `Walk`, din `Walking-loop` | `Idle`: respirație și privire; `Die`: flexia gâtului spre carapace și strângerea membrelor |

Mișcările suplimentare sunt animații de schelet create pentru integrarea stărilor AI. Țestoasa nu are un clip separat de alergare; mersul original este adaptat vitezei de deplasare. Materialul comun stilizat aplicat în `WildlifeAnimal` păstrează detaliile de culoare ale asset-urilor și simplifică iluminarea/texturile pentru aspectul cartoon. Autoritatea host-ului, damage-ul, loot-ul și sincronizarea rămân cele descrise mai sus.

Conversia reproductibilă, instrucțiunile și rapoartele se află în [tools/asset_pipeline](../tools/asset_pipeline/README.md). Validarea binară locală confirmă skin-uri și mai multe canale articulare schimbate în mers: 15 pentru broască, 15 pentru șarpe și 17 pentru țestoasă. Acest rezultat verifică fișierele GLB; verificările Godot și tranzițiile vizuale se consemnează separat în contextul proiectului.

Acesta este un vertical slice jucabil, cu modele animale importate și animații articulate. Polish-ul personajului, tranzițiile și performanța sunt lucrări ulterioare. Nu există încă economie salvată persistent pe Steam, matchmaking Steam sau teste de internet WAN. Se poate juca host/client cu transportul ENet existent.
