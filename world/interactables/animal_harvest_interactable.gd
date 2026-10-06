class_name AnimalHarvestInteractable
extends LobbyInteractable
## Corpse interaction stays in the world; the host validates every request.

func _ready() -> void:
    interaction_kind="harvest"
    var animal:=get_parent() as WildlifeAnimal
    interaction_range=reach(animal.definition) if is_instance_valid(animal) else 2.8
    super._ready()

## Big bodies (the bosses) can be worked from further away.
static func reach(definition: AnimalDefinition) -> float:
    return 2.8+maxf(0.0,definition.length*.35-.6)

func can_interact() -> bool:
    var animal:=get_parent() as WildlifeAnimal
    return is_instance_valid(animal) and animal.dead and not animal.harvested and NetworkSession.phase=="hunt"

func interaction_position() -> Vector3:
    var animal:=get_parent() as WildlifeAnimal
    return animal.global_position+Vector3.UP*minf(animal.definition.height*.3,.65) if is_instance_valid(animal) else global_position

func localized_name() -> String:
    var animal:=get_parent() as WildlifeAnimal
    if not is_instance_valid(animal): return tr("HARVEST_TITLE")
    var definition:=animal.definition
    if animal.harvest_owner>0:
        return LocaleSettings.text("HARVEST_OCCUPIED",{"name":tr(definition.display_name)})
    var window: float=definition.harvest_window
    var difficulty:=tr("HARVEST_EASY" if window>=.33 else "HARVEST_MEDIUM" if window>=.28 else "HARVEST_HARD" if window>=.23 else "HARVEST_VERY_HARD" if window>=.20 else "HARVEST_EXPERT")
    var loot:=AnimalCatalog.loot(definition.loot_id)
    return LocaleSettings.text("HARVEST_PROMPT",{"name":tr(definition.display_name),"action":tr("HARVEST_SHELL" if String(definition.id)=="turtle" else "HARVEST_SKIN"),"cuts":HarvestPattern.total_steps(definition.harvest_strokes),"difficulty":difficulty,"space":loot.space})
