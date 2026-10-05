class_name LootPickup
extends LobbyInteractable

@export var loot_definition: LootDefinition
var network_id: int = 0
var collected: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
    interaction_kind = "loot"
    interaction_range = 2.3
    super._ready()
    add_to_group("loot_pickups")

func _process(delta: float) -> void:
    _bob_time += delta
    $Pelt.position.y = 0.3 + sin(_bob_time * 2.0) * 0.045

func collect_into(inventory: HunterInventory) -> bool:
    if collected or not inventory.collect(loot_definition):
        return false
    collected = true
    remove_from_group("lobby_interactables")
    remove_from_group("loot_pickups")
    hide()
    queue_free()
    return true

func localized_name() -> String:
    return tr(loot_definition.display_name) if loot_definition else tr("loot")
