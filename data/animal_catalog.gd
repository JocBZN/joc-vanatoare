class_name AnimalCatalog
extends RefCounted
const ANIMALS: Array[Resource] = [
    preload("res://data/animals/rabbit.tres"), preload("res://data/animals/deer.tres"),
    preload("res://data/animals/boar.tres"), preload("res://data/animals/wolf.tres"), preload("res://data/animals/bear.tres")
]
const SWAMP_ANIMALS: Array[Resource] = [
    preload("res://data/animals/frog.tres"), preload("res://data/animals/turtle.tres"),
    preload("res://data/animals/snake.tres"), preload("res://data/animals/crocodile.tres"), preload("res://data/animals/ancient_crocodile.tres")
]
const LOOT_IDS = [&"rabbit_pelt", &"deer_pelt", &"boar_pelt", &"wolf_pelt", &"bear_pelt", &"boar_tusk", &"frog_hide", &"turtle_shell", &"snake_skin", &"crocodile_hide", &"ancient_crocodile_hide"]
static var quality_loot: Dictionary = {}
static func population(map_id: String) -> Array[Resource]: return SWAMP_ANIMALS if map_id=="swamp" else ANIMALS
static func animal(id: StringName) -> AnimalDefinition:
    for entry: AnimalDefinition in ANIMALS+SWAMP_ANIMALS:
        if entry.id == id:
            return entry
    return null
static func loot(id: StringName) -> LootDefinition:
    if id in LOOT_IDS: return load("res://data/loot/" + str(id) + ".tres")
    if quality_loot.has(id): return quality_loot[id]
    var parts: PackedStringArray=String(id).split("__q")
    if parts.size()==2 and StringName(parts[0]) in LOOT_IDS and parts[1] in ["1","2","3"]:
        var quality: int=int(parts[1])
        var multiplier: float=1.2 if quality==1 else 1.0 if quality==2 else .65
        return _loot_variant(id,loot(StringName(parts[0])),quality,0,multiplier)
    parts=String(id).split("__s")
    if parts.size()==2 and StringName(parts[0]) in LOOT_IDS and parts[1] in ["1","2","3","4","5"]:
        var stars: int=int(parts[1])
        return _loot_variant(id,loot(StringName(parts[0])),0,stars,star_multiplier(stars))
    parts=String(id).split("__r")
    if parts.size()==2 and StringName(parts[0]) in LOOT_IDS and parts[1] in ["1","2","3","4","5"]:
        var raw_stars: int=int(parts[1])
        var hide: LootDefinition=_loot_variant(id,loot(StringName(parts[0])),0,raw_stars,star_multiplier(raw_stars)*RAW_VALUE)
        hide.raw=true
        return hide
    return null

static func _loot_variant(id: StringName,base: LootDefinition,quality: int,stars: int,multiplier: float) -> LootDefinition:
    var item: LootDefinition = base.duplicate(true) as LootDefinition
    item.id=id;item.base_id=base.id;item.quality=quality;item.stars=stars
    item.sell_value = roundi(base.sell_value * multiplier)
    quality_loot[id] = item
    return item

## Legacy __q IDs retain their original meanings and prices.
static func harvest_quality(mistakes: int) -> int:
    return 1 if mistakes <= 0 else 2 if mistakes <= 2 else 3

## Integer comparisons keep thresholds exact across every species and peer.
static func harvest_stars(mistakes: int,required: int) -> int:
    if mistakes<=0: return 5
    var strokes: int=maxi(1,required)
    if mistakes*4<=strokes: return 4
    if mistakes*4<=strokes*3: return 3
    if mistakes*2<=strokes*3: return 2
    return 1

## Traced skinning scores continuous damage, stored on the corpse as wear in
## permille so it survives snapshots and reconnects as an exact integer.
## A flawless hide keeps every star; a butchered one drops to the 10% tier.
static func stars_from_wear(wear: int) -> int:
    var damage: int=clampi(wear,0,1000)
    if damage<=60: return 5
    if damage<=220: return 4
    if damage<=430: return 3
    if damage<=680: return 2
    return 1

## A raw hide sells for this share of what the same hide earns once cleaned.
const RAW_VALUE: float = .4

## What the field gives: a raw hide carrying the stars the cut earned.
static func raw_hide(base_id: StringName,wear: int) -> LootDefinition:
    if base_id not in LOOT_IDS: return null
    return loot(StringName(String(base_id)+"__r"+str(stars_from_wear(wear))))

## What the camp cleaner gives back for a raw hide.
static func cleaned_hide(raw: LootDefinition,clean: float) -> LootDefinition:
    if raw==null or not raw.raw: return null
    return loot(StringName(String(raw.base_id)+"__s"+str(CleaningPattern.final_stars(raw.stars,clean))))

## The species a hide came from, for drawing what the cleaner throws off it.
static func animal_for_loot(base_id: StringName) -> AnimalDefinition:
    for entry: AnimalDefinition in ANIMALS+SWAMP_ANIMALS:
        if entry.loot_id==base_id: return entry
    return null

static func harvested_loot_wear(base_id: StringName,wear: int) -> LootDefinition:
    if base_id not in LOOT_IDS: return null
    return loot(StringName(String(base_id)+"__s"+str(stars_from_wear(wear))))

static func star_percent(stars: int) -> int:
    match stars:
        5: return 150
        4: return 120
        3: return 100
        2: return 50
        1: return 10
        _: return 0

static func star_multiplier(stars: int) -> float:
    return float(star_percent(stars))/100.0

static func harvested_loot(base_id: StringName,mistakes: int,required: int=0) -> LootDefinition:
    if base_id not in LOOT_IDS: return null
    if required<=0:
        for entry: AnimalDefinition in ANIMALS+SWAMP_ANIMALS:
            if entry.loot_id==base_id:
                required=entry.harvest_strokes
                break
    return loot(StringName(String(base_id)+"__s"+str(harvest_stars(mistakes,required))))
static func roll(rng: RandomNumberGenerator,map_id: String="forest") -> AnimalDefinition:
    var entries:=population(map_id)
    var total := 0.0
    for entry: AnimalDefinition in entries:
        total += entry.spawn_weight
    var value := rng.randf_range(0.0, total)
    for entry: AnimalDefinition in entries:
        value -= entry.spawn_weight
        if value <= 0.0:
            return entry
    return entries[0]
