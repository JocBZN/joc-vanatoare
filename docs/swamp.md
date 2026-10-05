# Etapa 09 — Blackwater Marsh

Deschide project.godot în Godot 4.7.2, apoi F5. În lobby mergi la foc, apasă E, alege **Mlaștină / Swamp**, apoi **Start expedition**. Numai host-ul pornește harta. Cu server online, echipa pornește după confirmarea încărcării de către toți membrii. Fără Steam API în această etapă.

Mlaștina are 1.200 × 1.200 m, teren determinist separat, bălți puțin adânci, maluri și drum central uscat. Jeep-ul cu patru locuri sosește lângă echipă. Terenul moale încetinește vânătorii; jeep-ul are aderență și forță reduse și rezistență suplimentară în noroi. Podețele rămân ferme. Apa nu produce moarte automată și adâncimea este limitată pentru traversare. Animalele acvatice au sprijin la suprafață.

Trei puncte de explorat: colibă de pescuit abandonată (110, -155), turn vechi (-155, -100), bârlog de crocodil uriaș (170, -330). Podețele de 4,6 m au coliziune continuă pentru mașină. Un adăpost luminat marchează sosirea. Vegetația evită traseele și zonele clădirilor. Atmosferă: ceață verde discretă, apă cu valuri și reflexii, noroi umed cu texturi PBR, arbori scanați, stuf, nuferi, licurici și ambient sonor original în buclă.

| Animal | HP | Pondere spawn | Comportament | Spațiu loot | Bani |
|---|---:|---:|---|---:|---:|
| Broască | 32 | 43 | Fuge; salturi și picioare articulate | 1 | 18 |
| Țestoasă | 85 | 28 | Fuge lent; retrage capul | 2 | 55 |
| Șarpe | 165 | 16 | Urmărește și mușcă; corp ondulat | 3 | 100 |
| Crocodil | 430 | 10 | Urmărește pe uscat și în apă; mușcă | 5 | 220 |
| Crocodil uriaș | 950 | 3 | Variantă mare, agresivă; bârlog dedicat | 8 | 550 |

Ponderile însumează 100. Populația inițială include fiecare specie și un gardian în bârlog; următoarele apariții sunt ponderate. Host-ul creează și simulează fauna, validează damage-ul, colectarea și vânzarea. Clienții primesc poziții, stări, animații, viață și nume traduse. Gardianul bârlogului rămâne prezent cât timp jucătorii explorează alte zone; alte animale îndepărtate pot fi reciclate. Limita de populație rămâne 40.

Banii, ghiozdanul și dreptul la loot sunt individuale. Portbagajul este comun cu proprietar pentru fiecare obiect. Întoarcerea la lobby păstrează cargo-ul. Revive-ul cu E ținut trei secunde, perspectiva first/third person, armele, scope-ul și upgrade-urile funcționează și aici.

## Fișiere și extindere

`data/world_catalog.gd` înregistrează expedițiile. `WorldRouter` încarcă scenele, iar `SwampMap` păstrează contractul de teren/streaming al ForestMap cu alt seed, altă înălțime și vegetație. `data/animal_catalog.gd` selectează fauna după hartă. Resursele `.tres` definesc progresia, animațiile crocodilului sunt în GLB, iar modelul nativ al celorlalte specii este în `actors/animals/swamp_animal_model.gd`.

Acesta este un vertical slice jucabil. Modelele native de broască/țestoasă/șarpe și character-ul au în continuare nevoie de sculpt/rig/animație manuală pentru nivelul final realist. Nu există încă economie salvată persistent pe Steam, matchmaking Steam sau teste de internet WAN. Se poate juca host/client cu transportul ENet existent.
