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
static func population(map_id: String) -> Array[Resource]: return SWAMP_ANIMALS if map_id=="swamp" else ANIMALS
static func animal(id: StringName) -> AnimalDefinition:
    for entry: AnimalDefinition in ANIMALS+SWAMP_ANIMALS:
        if entry.id == id:
            return entry
    return null
static func loot(id: StringName) -> LootDefinition:
    if id not in [&"rabbit_pelt", &"deer_pelt", &"boar_pelt", &"wolf_pelt", &"bear_pelt", &"boar_tusk",&"frog_hide",&"turtle_shell",&"snake_skin",&"crocodile_hide",&"ancient_crocodile_hide"]:
        return null
    return load("res://data/loot/" + str(id) + ".tres")
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
