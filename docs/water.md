# Apă naturală — lacul Forest și Blackwater Marsh

Actualizat: 6 octombrie 2026.

Lacul și mlaștina folosesc un material comun cu valuri mici, două straturi de normale provenite din heightmap-uri de valuri, reflexii din cer și lumina soarelui, refracție și absorbție în funcție de adâncime. Lacul este mai limpede; mlaștina păstrează o nuanță cu sediment și o suprafață mai calmă. Nu există taste sau acțiuni noi: deplasarea, saltul și condusul folosesc comenzile existente.

## Suprafața și adâncimea

`world/effects/natural_water.gdshaderinc` conține implementarea comună; `world/forest/forest_lake.gdshader` și `world/swamp/swamp_water.gdshader` aleg paleta și intensitățile fiecărei lumi.

- Valurile geometrice sunt sume de sinusoide cu derivate analitice. Detaliul mai fin se calculează în normalele pixelilor, pentru a evita aliasing-ul mesh-ului. Lacul are 128 subdiviziuni pe fiecare axă, iar suprafața mlaștinii 256, cu lungimi de undă adaptate grilei.
- Depth-ul opac este reconstruit prin `INV_PROJECTION_MATRIX`, cu NDC diferit pentru Forward+/Mobile și Compatibility. Adâncimea verticală controlează malul și spuma; lungimea parcursă de rază controlează absorbția de tip Beer–Lambert.
- Refracția deplasează coordonatele imaginii scenei după normală. O verificare de depth respinge mostrele care ar deforma un obiect aflat în fața sau deasupra apei.
- Fresnel folosește `F0=0.0204`. Godot calculează reflectanța dielectrică ca `0.16 * SPECULAR²`, de aceea materialul folosește `SPECULAR=0.3571`.

În Forest, nivelul nominal este −3 m. Fundul lacului are adâncime maximă de **1,15 m**, astfel încât apa rămâne traversabilă cu hunter-ul existent. Un mal jos împiedică terenul procedural să deschidă un șanț mai adânc la margine; tranziția revine treptat la relieful inițial. Aceeași sămânță reproduce același fund pe toate mașinile, inclusiv la intrarea târzie într-o expediție.

`water_depth(point)` descrie coloana de apă deasupra terenului. `water_submersion(point)` verifică și înălțimea punctului: un hunter sau un jeep aflat deasupra apei, pe un podeț ori pe teren uscat nu primește forțele noi de apă. Mlaștina își păstrează nivelul nominal de 0 m și comportamentul existent al noroiului și podețelor.

## Nisipul și sedimentul

Fundul lacului și malul imediat au nisip procedural cu granulație fină, relief optic
discret și culoare/roughness adaptate umezelii. Masca urmărește bazinul și nivelul apei;
alte depresiuni joase din Forest își păstrează iarba. Nu se modifică mesh-ul de coliziune.

Sub apa mlaștinii, solul este noroi brun cu aglomerări și normale din scan-ul CC0 existent
[Poly Haven brown_mud_03](https://polyhaven.com/a/brown_mud_03), combinat cu variație
procedurală; iarba revine treptat pe malul mai înalt. Atribuirea rămâne în
`assets/art/ATTRIBUTION.md`; nu s-au cumpărat sau descărcat alte materiale pentru sediment.

`world/effects/sediment_surface.gdshaderinc` partajează zgomotul în coordonate mondiale
între shader-ele de sol. Hash-ul întreg `uint` păstrează aceleași valori la colțurile
celulelor și elimină discontinuitățile produse pe GPU de hash-ul anterior bazat pe sinus.
Filtrarea cu `fwidth` estompează granulele și ondulațiile mai mici decât un pixel.
`tests/diagnose_sediment.gd` permite comparații A/B ale etapelor materialului; nu este
o suită de gameplay. Terenul determinist, adâncimea, noroiul și podețele păstrează fizica existentă.

## Fizică și unde de contact

Hunter-ul încetinește progresiv după adâncimea picioarelor, cu accelerație și salt ușor reduse când este scufundat. Simularea continuă să folosească autoritatea hostului și predicția locală existente. În mlaștină, rezistența apei se combină cu noroiul fără multiplicarea celor două penalizări.

Jeep-ul primește rezistență și susținere modestă în patru puncte distribuite ale caroseriei. Forțele depind de imersiune și viteză și se aplică **numai pe host**, cât timp harta de vânătoare este activă. Replica clientului rămâne înghețată și urmează snapshot-urile. Susținerea reduce căderea, fără să transforme jeep-ul într-o ambarcațiune.

`world/effects/water_interaction.gd` reconstruiește local intrările în apă, pașii și urmele jeep-ului din pozițiile deja replicate. Nu adaugă RPC-uri sau stare de gameplay. Păstrează cel mult **opt evenimente**, fiecare de maximum **cinci secunde**, într-un buffer circular. Actorii imobili, așezați, morți, neîncărcați sau aflați deasupra apei nu produc pași continui. Corecțiile mari de poziție nu lasă o urmă între punctele depărtate. Loading-ul și schimbarea hărții șterg urmele vechi.

Undele vizuale folosesc un ceas local. Fizica verifică planul nominal al apei și terenul determinist, nu faza undelor desenate; diferențele de moment ale prezentării între peeri nu modifică rezultatul fizicii.

## Asset-uri și reproducere

Normalele sunt derivate din **Seamless looping waves heightmaps**, autor **zookeeper**, sub **CC0 1.0 Universal**. Sunt păstrate numai cadrele sursă `waves5_000.png` și `waves5_067.png`, 512 × 512. Arhiva completă de 14 MB nu este livrată în proiect. Spuma este o textură celulară periodică originală, generată determinist pentru joc.

- [Pagina autorului și licența asset-ului](https://opengameart.org/content/seamless-looping-waves-heightmaps)
- [Licența CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
- [Atribuire și detalii locale](../assets/art/water/ATTRIBUTION.md), consemnate și în [indexul general de artă](../assets/art/ATTRIBUTION.md)
- [Receipt cu proveniență și SHA-256](../assets/art/water/source_receipt.json)

`tools/asset_pipeline/build_water_textures.py` folosește NumPy și Pillow. Derivează normalele prin diferențe centrale periodice; nu imprimă culoarea sau reflexiile fotografice în apă. Rulează din orice director:

```powershell
python tools/asset_pipeline/build_water_textures.py --check
python tools/asset_pipeline/build_water_textures.py
```

Prima comandă verifică fișierele byte-for-byte fără să scrie. A doua reconstruiește texturile și receipt-ul din cele două cadre păstrate. Cadrele sursă sunt ignorate de importul Godot prin `.gdignore`.

## Verificări ale sesiunii

Validare finală locală Godot 4.7.2, 6 octombrie 2026:

- Import curat; nouă suite headless, **532 checks, 0 failures**, raport
  `tests/results/headless_20261006_095802_79fc1a`.
- `tests/verify_water.gd`: **22 checks, 0 failures**, inclusiv malul, adâncimea,
  contactul, loading-ul, replica clientului și expirarea undelor. Măsurătorile reale din
  5 octombrie: deplasare 4,858 m uscat / 2,714 m lac; rulare liberă jeep 5,485 / 4,522 m/s;
  cădere fără/cu susținere 0,178 / 0,081 m.
- `tests/verify_random_terrain.gd`: **6 checks, 0 failures**.
- ENet Forest și Swamp: **208 checks, 0 failures** fiecare; rapoarte
  `tests/results/run_20261006_100227_192ac5` și `run_20261006_100432_6109c6`.
- Preview final Forward+ pe RTX 3050 Ti: șase capturi reale, inclusiv prim-planurile
  nisipului neted și noroiului scanat, fără erori. Wake-ul folosește poziții reale în apă.
- Preview Compatibility/OpenGL 3.3: șase capturi, log curat și `WATER_PREVIEW_DONE`,
  în `work/sediment-compat.log` din conversație. Codul de ieșire nu a fost returnat;
  capturile și logul confirmă terminarea preview-ului. FPS-ul capturat nu este benchmark.
- Generatorul de texturi cu `--check` a reprodus exact fișierele în sesiunea inițială.

Totalul verificărilor comune cu recolta manuală: **976 checks, 0 failures**
(532 + 22 + 6 + 208 + 208). Rezultatele inițiale din 5 octombrie și corecțiile fixture-urilor
sunt păstrate în `CONTEXT_PROIECT.md`. Nu s-a făcut commit/push.

## Limite și surse tehnice

Materialul refractă copia scenei opace. Alte transparențe și obiectele din afara ecranului nu apar în refracție; verificarea de depth reduce deformarea accidentală a obiectelor apropiate, fără a elimina toate limitele screen-space. Reflexiile provin din cer și lumini, fără un sistem separat de reflexie planară pentru întreaga scenă.

Nu este un solver de fluid: nu simulează curenți volumetrici, transfer de masă, revărsare, valuri fizice cu coliziune sau înot. Rezistența, susținerea și undele de contact sunt aproximații controlate pentru jocul existent. Performanța la GPU-uri mai slabe și în condiții WAN nu este stabilită de capturile locale.

- [NVIDIA GPU Gems — Effective Water Simulation from Physical Models](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
- [Godot — reconstrucția depth-ului](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)
- [Godot — screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- [Godot — maparea dielectrică F0 în sursa renderer-ului](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl)
