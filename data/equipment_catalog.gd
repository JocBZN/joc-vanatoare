class_name EquipmentCatalog
extends RefCounted
## Shared, immutable content definitions. Balance is edited in the .tres files.

const WEAPONS: Array[Resource] = [
    preload("res://data/weapons/rusty_pistol.tres"),
    preload("res://data/weapons/old_rifle.tres"),
    preload("res://data/weapons/double_barrel.tres"),
    preload("res://data/weapons/scrap_blaster.tres"),
    preload("res://data/weapons/beehive.tres"),
    preload("res://data/weapons/thunder_tube.tres"),
    preload("res://data/weapons/sniper_rifle.tres"),
    preload("res://data/weapons/revolver.tres"),
    preload("res://data/weapons/ak_rifle.tres"),
    preload("res://data/weapons/railgun.tres"),
    preload("res://data/weapons/raygun.tres"),
    preload("res://data/weapons/chain_smg.tres"),
    preload("res://data/weapons/nova_shotgun.tres"),
    preload("res://data/weapons/harpoon.tres"),
]
const BACKPACKS: Array[Resource] = [
    preload("res://data/backpacks/small.tres"),
    preload("res://data/backpacks/ranger.tres"),
    preload("res://data/backpacks/expedition.tres"),
    preload("res://data/backpacks/hoarder.tres"),
]
const TEST_LOOT: Resource = preload("res://data/loot/rabbit_pelt.tres")


static func weapon(id: StringName) -> WeaponDefinition:
    for entry: WeaponDefinition in WEAPONS:
        if entry.id == id:
            return entry
    return null


static func backpack(id: StringName) -> BackpackDefinition:
    for entry: BackpackDefinition in BACKPACKS:
        if entry.id == id:
            return entry
    return null
