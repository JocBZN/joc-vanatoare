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
