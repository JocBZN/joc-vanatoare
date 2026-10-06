class_name AnimalDefinition
extends Resource
@export var id: StringName
@export var display_name: String
@export_file("*.tscn") var model_path: String
@export var max_health: int = 18
@export var spawn_weight: float = 48.0
@export var aggressive: bool = false
@export var attack_damage: int = 0
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.0
@export var aggro_range: float = 18.0
@export var pursuit_range: float = 125.0
@export var aggro_memory: float = 30.0
@export var height: float = 1.0
@export var aquatic: bool=false
@export_range(10, 90) var max_slope: float=90.0
@export var length: float=0
@export var width: float=0
@export var loot_id: StringName
@export_range(2, 16) var harvest_strokes: int = 2
@export_range(1.0, 4.0) var harvest_period: float = 2.6
@export_range(.08, .5) var harvest_window: float = .34
@export_range(.8, 1.0) var harvest_final_period_scale: float = .92
@export_range(.7, 1.0) var harvest_final_window_scale: float = .84
## The species' skinning twist, see HarvestPattern: slippery, ticks, shell,
## thick, wiggle, twitch, bees, chomp. "fat" only matters at the camp cleaner.
@export var harvest_quirks: PackedStringArray = PackedStringArray()

## Tension rises only with successful work, so misses or changing helpers cannot
## reset the harder finishing cuts. Timing changes between rounds, never mid-cycle.
func harvest_timing(completed: int, required: int = 0) -> Dictionary:
    var cuts: int=clampi(required if required>0 else harvest_strokes,2,16)
    var progress: float=clampf(float(completed)/float(cuts-1),0.0,1.0)
    var pressure: float=clampf((progress-.45)/.55,0.0,1.0)
    pressure=pressure*pressure*(3.0-2.0*pressure)
    var base_period: float=clampf(harvest_period,1.35,4.0)
    var base_window: float=clampf(harvest_window,.08,.5)
    return {
        "period":maxf(1.35,base_period*lerpf(1.0,clampf(harvest_final_period_scale,.8,1.0),pressure)),
        "window":maxf(.08,base_window*lerpf(1.0,clampf(harvest_final_window_scale,.7,1.0),pressure)),
        "base_period":base_period,"base_window":base_window,"pressure":pressure,
    }

## 0 for the rabbit and frog, 1 for the ancient crocodile.
func harvest_difficulty() -> float:
    return clampf((.36-clampf(harvest_window,.08,.5))/.20,0.0,1.0)

## Every knob of the skinning routine, from one difficulty value plus the shared
## pressure curve, so a species is coherently easy or brutal in every move and
## the finishing steps are always the hardest. Values change between steps only.
func harvest_tuning(completed: int, required: int = 0) -> Dictionary:
    var pressure: float=float(harvest_timing(completed,required).pressure)
    var difficulty: float=harvest_difficulty()
    var hard: float=clampf(difficulty+pressure*.15,0.0,1.15)
    return {
        "difficulty":difficulty,"pressure":pressure,
        "seams":2+int(round(difficulty*2.4)),
        "seam_length":lerpf(.42,.25,hard),
        "perfect_band":lerpf(.48,.24,hard),
        "min_speed":lerpf(.9,1.5,hard),
        "directional":difficulty>=.5,
        "seam_hp":2 if harvest_quirks.has("shell") or harvest_quirks.has("thick") else 1,
        "twitch_period":lerpf(3.4,2.4,difficulty),
        "jaw_period":lerpf(3.6,2.6,difficulty),
        "hazards":2+int(round(difficulty*1.5)),
    }
