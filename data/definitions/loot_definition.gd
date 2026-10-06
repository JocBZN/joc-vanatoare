class_name LootDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var space: int = 1
@export var sell_value: int = 10
## Base loot has no grade; legacy __q variants retain quality and current __s variants stars.
@export var base_id: StringName
@export_range(0, 3) var quality: int = 0
@export_range(0, 5) var stars: int = 0

func star_rating() -> String:
    var count: int=clampi(stars,0,5)
    return "★".repeat(count)+"☆".repeat(5-count)

func localized_name() -> String:
    var result: String = tr(display_name)
    if stars>0:
        result+=" ("+star_rating()+" · "+tr("HARVEST_STARS_"+str(stars))+")"
    elif quality>0:
        result+=" ("+tr("HARVEST_QUALITY_"+str(quality))+")"
    return result
