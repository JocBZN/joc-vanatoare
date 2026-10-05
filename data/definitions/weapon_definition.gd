class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var damage: int = 6
@export var price: int = 0
@export var magazine_size: int = 8
@export var reload_seconds: float = 1.4
@export var automatic: bool = false
@export var upgrade_price: int = 25
@export var cooldown: float = 1.0
@export_file("*.tscn") var model_path: String
@export_file("*.wav") var fire_sound: String
@export_range(1, 12) var pellets: int = 1
@export var spread: float = 0.0
@export_enum("iron", "scope") var sight_type: String="iron"
@export_range(15, 75) var ads_fov: float=62.0
