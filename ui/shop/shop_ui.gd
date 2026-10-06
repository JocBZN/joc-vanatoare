class_name ShopUI
extends CanvasLayer
## A modal for the stalls, plus a read-only inventory view.

signal closed
var inventory: HunterInventory
var kind: String = ""
var is_open: bool = false
var _root: Control
var _title: Label
var _subtitle: Label
var _summary: Label
var _rows: VBoxContainer
var _message: Label
var _close_button: Button
var _scroll: ScrollContainer
var _catalog: HBoxContainer
var preview: EquipmentPreview
var _details: VBoxContainer
var _counter: Label
var _rotate_hint: Label
var _selected_index: int=0
var _preview_path: String=""

func _ready() -> void:
    layer = 10
    _build_layout()
    _root.hide()
    LocaleSettings.changed.connect(_on_language_changed)
    NetworkSession.trunk_changed.connect(func() -> void:
        if is_open and kind in ["trunk","sell"]: _refresh())

func _on_language_changed() -> void:
    _close_button.text = tr("CLOSE")
    _message.text = ""
    if is_open:
        _refresh()

func _input(event: InputEvent) -> void:
    if is_open and (event.is_action_pressed("release_cursor") or event.is_action_pressed("inventory")):
        close()
        get_viewport().set_input_as_handled()

func open_for(shop_kind: String, source: HunterInventory, title: String) -> void:
    inventory = source
    kind = shop_kind
    _selected_index=0
    _preview_path=""
    is_open = true
    _title.text = tr(title)
    _message.text = ""
    if not inventory.changed.is_connected(_refresh):
        inventory.changed.connect(_refresh)
    if not inventory.feedback.is_connected(_on_feedback):
        inventory.feedback.connect(_on_feedback)
    _refresh()
    _root.show()

func close() -> void:
    if not is_open:
        return
    is_open = false
    _root.hide()
    if is_instance_valid(inventory):
        if inventory.changed.is_connected(_refresh): inventory.changed.disconnect(_refresh)
        if inventory.feedback.is_connected(_on_feedback): inventory.feedback.disconnect(_on_feedback)
    closed.emit()

func _build_layout() -> void:
    _root = Control.new()
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    _root.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.025, 0.035, 0.035, 0.78)
    var panel := PanelContainer.new()
    _root.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left = -560
    panel.offset_right = 560
    panel.offset_top = -336
    panel.offset_bottom = 336
    panel.add_theme_stylebox_override("panel", _style(Color("17211e"), Color("a8844b"), 2))
    var margin := MarginContainer.new()
    panel.add_child(margin)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    var column := VBoxContainer.new()
    margin.add_child(column)
    column.add_theme_constant_override("separation", 10)
    var header := HBoxContainer.new()
    column.add_child(header)
    _title = _label("", 30, Color("f4dfb3"))
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_title)
    _close_button = _button(tr("CLOSE"))
    header.add_child(_close_button)
    _close_button.pressed.connect(close)
    _subtitle = _label("", 15, Color("b4bfae"))
    column.add_child(_subtitle)
    _summary = _label("", 17, Color("eebc62"))
    column.add_child(_summary)
    column.add_child(HSeparator.new())
    _build_catalog(column)
    _scroll = ScrollContainer.new()
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(_scroll)
    _rows = VBoxContainer.new()
    _rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _rows.add_theme_constant_override("separation", 10)
    _scroll.add_child(_rows)
    _message = _label("", 15, Color("f4ce85"))
    _message.custom_minimum_size.y = 24
    _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_message)

func _refresh() -> void:
    if not is_open or not is_instance_valid(inventory): return
    for child in _rows.get_children():
        _rows.remove_child(child)
        child.queue_free()
    _title.text = tr(kind)
    _summary.text = LocaleSettings.text("SUMMARY", {"coins": inventory.coins, "used": inventory.used_space(), "cap": inventory.capacity(), "value": inventory.loot_value()})
    var browse:=kind in ["weapons","backpacks"]
    _catalog.visible=browse
    _scroll.visible=not browse
    if browse:
        _subtitle.text=tr("WEAPONS_DESC" if kind=="weapons" else "BAGS_DESC")
        _refresh_catalog()
        return
    match kind:
        "trunk":
            _build_trunk_rows()
        "storage":
            _build_storage_rows()
        "sell", "inventory":
            _subtitle.text = tr("SELL_DESC" if kind == "sell" else "INVENTORY_DESC")
            _build_loot_rows()

func _build_loot_rows() -> void:
    var counts: Dictionary = {}
    var definitions: Dictionary = {}
    for item in inventory.items:
        counts[item.id] = int(counts.get(item.id, 0)) + 1
        definitions[item.id] = item
    if counts.is_empty():
        var empty := _label(tr("EMPTY_BAG"), 19, Color("b4bfae"))
        empty.custom_minimum_size.y = 160
        _rows.add_child(empty)
    for id: StringName in counts:
        var definition: LootDefinition = definitions[id]
        var quantity: int = counts[id]
        var button := _row("%s × %d" % [definition.localized_name(), quantity], LocaleSettings.text("LOOT_DETAIL", {"space": definition.space * quantity, "value": definition.sell_value * quantity}), tr("IN_BAG"))
        button.disabled = true
    if kind == "sell":
        var sell_button := _button(LocaleSettings.text("SELL_ALL", {"n": inventory.loot_value()}))
        sell_button.custom_minimum_size.y = 48
        sell_button.disabled = inventory.items.is_empty()
        sell_button.pressed.connect(inventory.sell_all)
        _rows.add_child(sell_button)
        var own_value:=0
        for entry in NetworkSession.trunk_view:
            if entry.mine: own_value+=AnimalCatalog.loot(StringName(entry.kind)).sell_value
        var cargo_button:=_button(LocaleSettings.text("SELL_TRUNK",{"n":own_value}))
        cargo_button.pressed.connect(func() -> void: NetworkSession.request_action("sell_trunk"))
        _rows.add_child(cargo_button)
        var stash_button:=_button(LocaleSettings.text("SELL_STASH",{"n":inventory.stash_value()}))
        stash_button.disabled=inventory.stored.is_empty()
        stash_button.pressed.connect(func() -> void: NetworkSession.request_action("sell_stash"))
        _rows.add_child(stash_button)
        _rows.add_child(_label(tr("PARK_TO_SELL"),13,Color("b4bfae")))

func _build_catalog(column: VBoxContainer) -> void:
    _catalog=HBoxContainer.new()
    _catalog.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _catalog.add_theme_constant_override("separation",26)
    column.add_child(_catalog)
    var showcase:=VBoxContainer.new()
    showcase.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _catalog.add_child(showcase)
    var studio:=PanelContainer.new()
    studio.size_flags_vertical=Control.SIZE_EXPAND_FILL
    studio.add_theme_stylebox_override("panel",_style(Color("0c1719"),Color("36524b"),1))
    showcase.add_child(studio)
    var stage:=HBoxContainer.new()
    studio.add_child(stage)
    var previous:=_button("‹")
    previous.add_theme_font_size_override("font_size",38)
    previous.custom_minimum_size.x=50
    previous.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    previous.pressed.connect(browse.bind(-1))
    stage.add_child(previous)
    preview=EquipmentPreview.new()
    preview.custom_minimum_size=Vector2(380,320)
    preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    stage.add_child(preview)
    var next:=_button("›")
    next.add_theme_font_size_override("font_size",38)
    next.custom_minimum_size.x=50
    next.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    next.pressed.connect(browse.bind(1))
    stage.add_child(next)
    var line:=HBoxContainer.new()
    showcase.add_child(line)
    _rotate_hint=_label("",13,Color("91ada7"))
    _rotate_hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    line.add_child(_rotate_hint)
    _counter=_label("",15,Color("ebc782"))
    line.add_child(_counter)
    _details=VBoxContainer.new()
    _details.custom_minimum_size.x=360
    _details.add_theme_constant_override("separation",6)
    _catalog.add_child(_details)

func browse(direction: int) -> void:
    var count:=EquipmentCatalog.WEAPONS.size() if kind=="weapons" else EquipmentCatalog.BACKPACKS.size()
    _selected_index=posmod(_selected_index+direction,count)
    _message.text=""
    _refresh_catalog()

func _refresh_catalog() -> void:
    for child in _details.get_children():
        _details.remove_child(child)
        child.queue_free()
    var weapon_shop:=kind=="weapons"
    var entries: Array=EquipmentCatalog.WEAPONS if weapon_shop else EquipmentCatalog.BACKPACKS
    var entry: Resource=entries[_selected_index]
    _counter.text="%02d / %02d" % [_selected_index+1,entries.size()]
    _rotate_hint.text=tr("ROTATE_HINT")
    var path: String=entry.model_path
    if _preview_path!=path:
        preview.show_model(path)
        _preview_path=path
    var tag:=_label(tr("OWNED") if weapon_shop and inventory.owns_weapon(entry.id) else tr("GEAR_FOR_SALE"),13,Color("80cbb9"))
    _details.add_child(tag)
    var name_label:=_label(tr(entry.display_name),28,Color("ffdf9b"))
    name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _details.add_child(name_label)
    var description:=_label(tr(entry.description) if weapon_shop else LocaleSettings.text("BAG_CAROUSEL_DESC",{"n":entry.capacity}),14,Color("b5c7b8"))
    description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _details.add_child(description)
    _details.add_child(HSeparator.new())
    var action: Button
    if weapon_shop:
        var stats:=_label(LocaleSettings.text("WEAPON_STATS",{"damage":inventory.weapon_damage(entry.id),"rate":"%.1f" % (1.0/inventory.weapon_cooldown(entry.id)),"ammo":inventory.magazine_capacity(entry.id)}),16,Color("eee1c3"))
        stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        _details.add_child(stats)
        var owned:=inventory.owns_weapon(entry.id)
        var equipped: bool=inventory.equipped_weapon_id==entry.id
        action=_button(tr("EQUIPPED" if equipped else "EQUIP") if owned else LocaleSettings.text("BUY_PRICE",{"n":entry.price}))
        action.disabled=equipped or (not owned and inventory.coins<entry.price)
        action.pressed.connect(NetworkSession.request_action.bind("equip" if owned else "buy_weapon",String(entry.id)))
        _details.add_child(action)
        if owned:
            var slots:=HBoxContainer.new()
            slots.add_theme_constant_override("separation",8)
            _details.add_child(slots)
            for slot_index in [0,1]:
                var in_slot: bool=inventory.loadout[slot_index]==entry.id
                var slot_button:=_button(tr("SLOT_MAIN" if slot_index==0 else "SLOT_SECONDARY"))
                slot_button.disabled=in_slot
                slot_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
                slot_button.add_theme_font_size_override("font_size",13)
                slot_button.pressed.connect(NetworkSession.request_action.bind("equip_slot",String(entry.id)+":"+str(slot_index)))
                slots.add_child(slot_button)
        _details.add_child(_label(tr("UPGRADES_TITLE"),14,Color("ebc782")))
        for attribute in HunterInventory.UPGRADE_TYPES:
            var level:=inventory.upgrade_level(entry.id,attribute)
            var cost:=inventory.upgrade_cost(entry.id,attribute)
            var card:=PanelContainer.new()
            card.add_theme_stylebox_override("panel",_style(Color("25352e"),Color("455b48"),1))
            _details.add_child(card)
            var line:=HBoxContainer.new()
            card.add_child(line)
            var detail:=VBoxContainer.new()
            detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
            line.add_child(detail)
            detail.add_child(_label(tr("UP_"+attribute.to_upper()),15,Color("f3e2bb")))
            detail.add_child(_label("%s  %d / %d" % [tr("LEVEL"),level,HunterInventory.MAX_UPGRADE],12,Color("b5c7b8")))
            var button:=_button(tr("MAX_LEVEL") if level>=HunterInventory.MAX_UPGRADE else "%d $" % cost)
            button.disabled=not owned or level>=HunterInventory.MAX_UPGRADE or inventory.coins<cost
            button.pressed.connect(NetworkSession.request_action.bind("upgrade",String(entry.id)+":"+attribute))
            line.add_child(button)
    else:
        var current: bool=inventory.backpack_id==entry.id
        var smaller: bool=entry.capacity<inventory.capacity()
        action=_button(tr("EQUIPPED" if current else "OUTGROWN") if current or smaller else LocaleSettings.text("BUY_PRICE",{"n":entry.price}))
        action.disabled=current or smaller or inventory.coins<entry.price
        action.pressed.connect(NetworkSession.request_action.bind("bag",String(entry.id)))
        _details.add_child(action)
    action.custom_minimum_size.y=44
    if inventory.coins<entry.price and (not weapon_shop or not inventory.owns_weapon(entry.id)):
        _details.add_child(_label(LocaleSettings.text("MISSING",{"n":entry.price-inventory.coins}),13,Color("d69d75")))

func _row(title: String, detail: String, action: String) -> Button:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(Color("243029"), Color("3b493b"), 1))
    _rows.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 13)
    panel.add_child(margin)
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 18)
    margin.add_child(line)
    var text := VBoxContainer.new()
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    line.add_child(text)
    text.add_child(_label(title, 19, Color("f3e5c7")))
    var description := _label(detail, 13, Color("bac3ae"))
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(description)
    var button := _button(action)
    button.custom_minimum_size = Vector2(140, 42)
    line.add_child(button)
    return button

func _on_feedback(message: String) -> void:
    _message.text = message

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color("fff0cf"))
    button.add_theme_color_override("font_disabled_color", Color("879080"))
    button.add_theme_stylebox_override("normal", _style(Color("615235"), Color("9d8656"), 1))
    button.add_theme_stylebox_override("hover", _style(Color("837047"), Color("e1bd73"), 1))
    button.add_theme_stylebox_override("pressed", _style(Color("443b2b"), Color("e1bd73"), 1))
    button.add_theme_stylebox_override("disabled", _style(Color("293029"), Color("3b4435"), 1))
    return button

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _build_trunk_rows() -> void:
    _subtitle.text=tr("TRUNK_DESC")
    var used:=0
    var own:=0
    var counts: Dictionary={}
    for item in NetworkSession.trunk_view:
        var definition:=AnimalCatalog.loot(StringName(item.kind))
        used+=definition.space
        if item.mine: own+=definition.sell_value
        var key: String=item.owner+"|"+item.kind
        if not counts.has(key): counts[key]={"data":item,"n":0}
        counts[key].n+=1
    _summary.text=LocaleSettings.text("TRUNK_SUMMARY",{"used":used,"cap":NetworkSession.TRUNK_CAPACITY,"value":own})
    var put:=_button(tr("DEPOSIT_ALL"))
    put.disabled=inventory.items.is_empty()
    put.pressed.connect(func() -> void: NetworkSession.request_action("deposit"))
    _rows.add_child(put)
    var take:=_button(tr("WITHDRAW_ALL"))
    take.disabled=own==0
    take.pressed.connect(func() -> void: NetworkSession.request_action("withdraw"))
    _rows.add_child(take)
    for group in counts.values():
        var item: Dictionary=group.data
        var definition:=AnimalCatalog.loot(StringName(item.kind))
        var button:=_row("%s × %d" % [definition.localized_name(),group.n],LocaleSettings.text("OWNER",{"name":item.owner})+"  ·  "+str(definition.sell_value*group.n),tr("MY_BAG") if item.mine else item.owner)
        button.disabled=true

func _build_storage_rows() -> void:
    _subtitle.text=tr("STORAGE_DESC")
    _summary.text=LocaleSettings.text("STASH_SUMMARY",{"used":inventory.stash_used(),"cap":HunterInventory.STASH_CAPACITY,"value":inventory.stash_value(),"bag_used":inventory.used_space(),"bag_cap":inventory.capacity()})
    var put:=_button(tr("STASH_DEPOSIT_ALL"))
    put.disabled=inventory.items.is_empty()
    put.pressed.connect(func() -> void: NetworkSession.request_action("stash_deposit"))
    _rows.add_child(put)
    var take:=_button(tr("STASH_WITHDRAW_ALL"))
    take.disabled=inventory.stored.is_empty()
    take.pressed.connect(func() -> void: NetworkSession.request_action("stash_withdraw",""))
    _rows.add_child(take)
    var counts: Dictionary={}
    var definitions: Dictionary={}
    for item in inventory.stored:
        counts[item.id]=int(counts.get(item.id,0))+1
        definitions[item.id]=item
    if counts.is_empty():
        var empty:=_label(tr("STASH_EMPTY_LIST"),19,Color("b4bfae"))
        empty.custom_minimum_size.y=120
        _rows.add_child(empty)
    for id: StringName in counts:
        var definition: LootDefinition=definitions[id]
        var quantity: int=counts[id]
        var button:=_row("%s × %d" % [definition.localized_name(),quantity],LocaleSettings.text("LOOT_DETAIL",{"space":definition.space*quantity,"value":definition.sell_value*quantity}),tr("STASH_TAKE"))
        button.disabled=inventory.used_space()+definition.space>inventory.capacity()
        button.pressed.connect(NetworkSession.request_action.bind("stash_withdraw",String(id)))
