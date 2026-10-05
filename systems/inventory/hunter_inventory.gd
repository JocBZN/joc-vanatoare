class_name HunterInventory
extends Node
## Individual wallet, loot and progression. Mutations execute on the host.

signal changed
signal feedback(message: String)

var coins: int = 0
var backpack_id: StringName = &"small"
var equipped_weapon_id: StringName = &"rusty_pistol"
var owned_weapons: Array[StringName] = [&"rusty_pistol"]
var loadout: Array[StringName] = [&"rusty_pistol",&"rusty_pistol"]
var active_slot: int = 0
var weapon_upgrades: Dictionary = {}
var magazines: Dictionary = {"rusty_pistol":8}
var reload_remaining: float = 0.0
const UPGRADE_TYPES = ["damage","rate","magazine"]
const MAX_UPGRADE = 3
var items: Array[LootDefinition] = []


func capacity() -> int:
    return EquipmentCatalog.backpack(backpack_id).capacity


func used_space() -> int:
    var total := 0
    for item in items:
        total += item.space
    return total


func loot_value() -> int:
    var total := 0
    for item in items:
        total += item.sell_value
    return total


func collect(item: LootDefinition) -> bool:
    if item == null or item.space <= 0 or item.sell_value < 0:
        return false
    if used_space() + item.space > capacity():
        _feedback("FULL_BAG")
        return false
    items.append(item)
    changed.emit()
    _feedback("COLLECTED",{"item_key":item.display_name,"n":item.sell_value})
    return true


func equip_weapon(id: StringName) -> bool:
    if not NetworkSession.is_host():
        NetworkSession.request_action("equip", String(id))
        return false
    var definition := EquipmentCatalog.weapon(id)
    if definition == null:
        return false
    if not owns_weapon(id):
        _feedback("WEAPON_LOCKED")
        return false
    if equipped_weapon_id == id:
        return false
    reload_remaining = 0.0
    equipped_weapon_id = id
    loadout[active_slot] = id
    changed.emit()
    _feedback("WEAPON_EQUIPPED",{"item_key":definition.display_name})
    return true

## Assigns an owned weapon to the main (0) or secondary (1) slot without switching the active hand unless that slot is the active one.
func assign_slot(id: StringName, slot: int) -> bool:
    if not NetworkSession.is_host(): return false
    if slot < 0 or slot > 1 or EquipmentCatalog.weapon(id) == null or not owns_weapon(id): return false
    loadout[slot] = id
    if slot == active_slot and equipped_weapon_id != id:
        reload_remaining = 0.0
        equipped_weapon_id = id
    changed.emit()
    return true

## Switches which loadout slot is in hand (main/secondary), like a weapon-swap key.
func switch_slot(slot: int) -> bool:
    if not NetworkSession.is_host():
        NetworkSession.request_action("slot", str(slot))
        return false
    if slot < 0 or slot > 1 or active_slot == slot: return false
    var id: StringName = loadout[slot]
    if EquipmentCatalog.weapon(id) == null: return false
    active_slot = slot
    if equipped_weapon_id != id:
        reload_remaining = 0.0
        equipped_weapon_id = id
    changed.emit()
    return true

## DEBUG convenience so every weapon can be test-fired without grinding the shop economy first.
func debug_unlock_all() -> void:
    if not NetworkSession.is_host():
        NetworkSession.request_action("debug_unlock_all")
        return
    for weapon: WeaponDefinition in EquipmentCatalog.WEAPONS:
        if not owns_weapon(weapon.id):
            owned_weapons.append(weapon.id)
            magazines[String(weapon.id)] = weapon.magazine_size
    changed.emit()

func owns_weapon(id: StringName) -> bool:
    return owned_weapons.has(id)

func upgrade_level(id: StringName, attribute: String) -> int:
    return int(weapon_upgrades.get(String(id),{}).get(attribute,0))

func weapon_damage(id: StringName) -> int:
    return roundi(EquipmentCatalog.weapon(id).damage * (1.0 + .35 * upgrade_level(id,"damage")))

func weapon_cooldown(id: StringName) -> float:
    return EquipmentCatalog.weapon(id).cooldown / (1.0 + .2 * upgrade_level(id,"rate"))

func magazine_capacity(id: StringName) -> int:
    var base: int = EquipmentCatalog.weapon(id).magazine_size
    return base + maxi(1,ceili(base * .25)) * upgrade_level(id,"magazine")

func ammunition() -> int:
    return int(magazines.get(String(equipped_weapon_id),0))

func upgrade_cost(id: StringName, attribute: String) -> int:
    if not UPGRADE_TYPES.has(attribute) or EquipmentCatalog.weapon(id)==null: return 0
    var multiplier: float = .8 if attribute=="magazine" else .9 if attribute=="rate" else 1.0
    return roundi(EquipmentCatalog.weapon(id).upgrade_price * multiplier * (upgrade_level(id,attribute)+1))

func buy_weapon(id: StringName) -> bool:
    if not NetworkSession.is_host():
        NetworkSession.request_action("buy_weapon",String(id))
        return false
    var definition := EquipmentCatalog.weapon(id)
    if definition==null or owns_weapon(id): return false
    if coins<definition.price:
        _feedback("MISSING",{"n":definition.price-coins})
        return false
    coins-=definition.price
    owned_weapons.append(id)
    magazines[String(id)]=magazine_capacity(id)
    equipped_weapon_id=id
    reload_remaining=0.0
    changed.emit()
    _feedback("WEAPON_BOUGHT",{"item_key":definition.display_name})
    return true

func buy_upgrade(id: StringName, attribute: String) -> bool:
    if not NetworkSession.is_host():
        NetworkSession.request_action("upgrade",String(id)+":"+attribute)
        return false
    if EquipmentCatalog.weapon(id)==null or not owns_weapon(id) or not UPGRADE_TYPES.has(attribute): return false
    if upgrade_level(id,attribute)>=MAX_UPGRADE: return false
    var cost:=upgrade_cost(id,attribute)
    if coins<cost:
        _feedback("MISSING",{"n":cost-coins})
        return false
    coins-=cost
    var levels: Dictionary=weapon_upgrades.get(String(id),{}).duplicate()
    levels[attribute]=upgrade_level(id,attribute)+1
    weapon_upgrades[String(id)]=levels
    changed.emit()
    _feedback("UPGRADE_BOUGHT",{"item_key":"UP_"+attribute.to_upper(),"n":levels[attribute]})
    return true

func consume_round() -> bool:
    if not NetworkSession.is_host() or reload_remaining>0 or ammunition()<=0: return false
    magazines[String(equipped_weapon_id)]=ammunition()-1
    changed.emit()
    return true

func begin_reload() -> bool:
    if not NetworkSession.is_host() or reload_remaining>0 or ammunition()>=magazine_capacity(equipped_weapon_id): return false
    reload_remaining=EquipmentCatalog.weapon(equipped_weapon_id).reload_seconds
    changed.emit()
    return true

func tick_reload(delta: float) -> bool:
    if reload_remaining<=0: return false
    reload_remaining=maxf(0,reload_remaining-delta)
    if reload_remaining==0:
        magazines[String(equipped_weapon_id)]=magazine_capacity(equipped_weapon_id)
        changed.emit()
        return true
    return false


func buy_backpack(id: StringName) -> bool:
    if not NetworkSession.is_host():
        NetworkSession.request_action("bag", String(id))
        return false
    var definition := EquipmentCatalog.backpack(id)
    if definition == null:
        return false
    if definition.capacity <= capacity():
        _feedback("BAG_OWNED")
        return false
    if coins < definition.price:
        _feedback("MISSING",{"n":definition.price-coins})
        return false
    # Commit the purchase together; existing loot stays in the backpack.
    coins -= definition.price
    backpack_id = id
    changed.emit()
    _feedback("BAG_BOUGHT",{"item_key":definition.display_name,"n":definition.capacity})
    return true


func sell_all() -> int:
    if not NetworkSession.is_host():
        NetworkSession.request_action("sell")
        return 0
    if items.is_empty():
        _feedback("NOTHING_TO_SELL")
        return 0
    var earned := loot_value()
    # Clear the sold items before emitting signals; repeated clicks cannot pay twice.
    items.clear()
    coins += earned
    changed.emit()
    _feedback("SOLD",{"n":earned})
    return earned

func export_state() -> Dictionary:
    var ids: Array=[]
    for item in items: ids.append(String(item.id))
    return {"coins":coins,"bag":String(backpack_id),"weapon":String(equipped_weapon_id),"items":ids,"owned":owned_weapons.duplicate(),"upgrades":weapon_upgrades.duplicate(true),"magazines":magazines.duplicate(),"reload":reload_remaining,"loadout":[String(loadout[0]),String(loadout[1])],"slot":active_slot}

func _feedback(key: String, values: Dictionary={}) -> void:
    var owner_peer: int=get_parent().peer_id if get_parent() is Hunter else 1
    if NetworkSession.is_host() and owner_peer!=NetworkSession.local_id(): NetworkSession.tell(owner_peer,key,values)
    else: feedback.emit(NetworkSession._message(key,values))

func apply_state(data: Dictionary) -> void:
    coins=int(data.coins)
    backpack_id=StringName(data.bag)
    equipped_weapon_id=StringName(data.weapon)
    owned_weapons.clear()
    for id in data.get("owned",[&"rusty_pistol"]):
        if EquipmentCatalog.weapon(StringName(id))!=null: owned_weapons.append(StringName(id))
    weapon_upgrades=data.get("upgrades",{}).duplicate(true)
    magazines=data.get("magazines",{"rusty_pistol":8}).duplicate()
    reload_remaining=float(data.get("reload",0))
    var raw_loadout: Array=data.get("loadout",[String(equipped_weapon_id),String(equipped_weapon_id)])
    loadout=[StringName(raw_loadout[0]) if raw_loadout.size()>0 else equipped_weapon_id,StringName(raw_loadout[1]) if raw_loadout.size()>1 else equipped_weapon_id]
    active_slot=int(data.get("slot",0))
    items.clear()
    for id in data.items:
        var item=AnimalCatalog.loot(StringName(id))
        if item: items.append(item)
    changed.emit()
