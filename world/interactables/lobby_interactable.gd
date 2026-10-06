class_name LobbyInteractable
extends Node3D

@export_enum("weapons", "backpacks", "sell", "test_loot", "loot", "jeep", "trunk", "expedition", "revive", "harvest", "cleaner", "storage", "terrace") var interaction_kind: String = "weapons"
@export var display_name: String = "Tarabă"
@export var interaction_range: float = 3.0


func _ready() -> void:
    add_to_group("lobby_interactables")
    LocaleSettings.changed.connect(_localize_signs)
    _localize_signs()


func localized_name() -> String:
    return tr(interaction_kind)

func can_interact() -> bool:
    return true

func _localize_signs() -> void:
    for child in find_children("*", "Label3D", true, false):
        if child.name == "Title" or child.name == "Label" or interaction_kind == "test_loot":
            child.text = localized_name().to_upper()

func interaction_position() -> Vector3:
    var marker := get_node_or_null("InteractionPoint") as Node3D
    return marker.global_position if marker else global_position


func distance_from(point: Vector3) -> float:
    return interaction_position().distance_to(point)
