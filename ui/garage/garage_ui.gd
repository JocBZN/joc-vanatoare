class_name GarageUI
extends CanvasLayer
## The Wandering Oak's workshop: one list with the two performance upgrades and
## the four builds. Buying only sends "truck_upgrade"; the host validates the
## bench, the prerequisite, the level and the buyer's wallet, then the new levels
## come back to everyone in the truck snapshot.
signal closed
const ACCENTS: Dictionary={&"speed":Color("e0662f"),&"accel":Color("d9a33a"),&"bar":Color("8d9399"),&"tower":Color("7d5836"),&"nitro":Color("c9463a"),&"boat":Color("2f8a92"),&"grill":Color("e0482e"),&"vacuum":Color("c9463a"),&"sphere":Color("7fd0e8"),&"horn":Color("d9b24a"),&"rotor":Color("e9e2cf")}
var is_open: bool=false
var inventory: HunterInventory
var _root: Control
var _title: Label
var _subtitle: Label
var _coins: Label
var _message: Label
var _close: Button
var _column: VBoxContainer
var _rows: Dictionary={}

func _ready() -> void:
    layer=11
    _build()
    _root.hide()
    LocaleSettings.changed.connect(refresh)
    NetworkSession.truck_changed.connect(refresh)

func _input(event: InputEvent) -> void:
    if is_open and (event.is_action_pressed("release_cursor") or event.is_action_pressed("inventory")):
        close()
        get_viewport().set_input_as_handled()

func open_for(source: HunterInventory) -> void:
    inventory=source
    is_open=true
    _message.text=""
    if not inventory.changed.is_connected(refresh): inventory.changed.connect(refresh)
    if not inventory.feedback.is_connected(_on_feedback): inventory.feedback.connect(_on_feedback)
    refresh()
    _root.show()

func close() -> void:
    if not is_open: return
    is_open=false
    _root.hide()
    if is_instance_valid(inventory):
        if inventory.changed.is_connected(refresh): inventory.changed.disconnect(refresh)
        if inventory.feedback.is_connected(_on_feedback): inventory.feedback.disconnect(_on_feedback)
    closed.emit()

func _on_feedback(text: String) -> void:
    _message.text=text

func _build() -> void:
    _root=Control.new();add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade:=ColorRect.new();_root.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.02,.03,.03,.82)
    var panel:=PanelContainer.new();_root.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left=-430;panel.offset_right=430;panel.offset_top=-335;panel.offset_bottom=335
    var style:=StyleBoxFlat.new();style.bg_color=Color("14211e");style.set_corner_radius_all(14)
    style.border_color=Color("b79052");style.border_width_top=3
    style.content_margin_left=26;style.content_margin_right=26;style.content_margin_top=20;style.content_margin_bottom=18
    panel.add_theme_stylebox_override("panel",style)
    var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",8);panel.add_child(outer)
    var head:=HBoxContainer.new();outer.add_child(head)
    _title=_label(28,Color("ffe2a9"));_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(_title)
    _coins=_label(20,Color("f2c94c"));head.add_child(_coins)
    _subtitle=_label(14,Color("a9c4b6"));_subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(_subtitle)
    var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)
    _column=VBoxContainer.new();_column.add_theme_constant_override("separation",7);_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_column)
    for group in 2:
        var header:=_label(15,Color("b79052"));header.name="Header"+str(group);_column.add_child(header)
        for id in (TruckUpgrades.ORDER.slice(0,2) if group==0 else TruckUpgrades.BUILDS):
            _column.add_child(_row(id))
    _message=_label(15,Color("ffd9a0"));_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(_message)
    _close=Button.new();_close.pressed.connect(close);outer.add_child(_close)

func _row(id: StringName) -> Control:
    var box:=PanelContainer.new()
    var style:=StyleBoxFlat.new();style.bg_color=Color("1d2e29");style.set_corner_radius_all(9)
    style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8
    box.add_theme_stylebox_override("panel",style)
    var line:=HBoxContainer.new();line.add_theme_constant_override("separation",14);box.add_child(line)
    var swatch:=ColorRect.new();swatch.color=ACCENTS.get(id,Color.WHITE);swatch.custom_minimum_size=Vector2(8,58);line.add_child(swatch)
    var texts:=VBoxContainer.new();texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;texts.add_theme_constant_override("separation",2);line.add_child(texts)
    var name_label:=_label(19,Color("ffe2a9"));texts.add_child(name_label)
    var description:=_label(13,Color("b8cfc3"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texts.add_child(description)
    var stat:=_label(13,Color("8fd3a8"));texts.add_child(stat)
    var right:=VBoxContainer.new();right.custom_minimum_size.x=170;right.add_theme_constant_override("separation",4);line.add_child(right)
    var pips:=_label(17,Color("f2c94c"));pips.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;right.add_child(pips)
    var buy:=Button.new();buy.custom_minimum_size.y=34;right.add_child(buy)
    buy.pressed.connect(func() -> void: NetworkSession.request_action("truck_upgrade",String(id)))
    _rows[id]={"name":name_label,"description":description,"stat":stat,"pips":pips,"buy":buy}
    return box

func _label(size: int,color: Color) -> Label:
    var label:=Label.new();label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
    return label

## What the stat line under an upgrade says: its effect now and after the next level.
func stat_text(id: StringName) -> String:
    var state: Dictionary=NetworkSession.truck_state
    var current: int=TruckUpgrades.level(state,id)
    var next: int=mini(current+1,TruckUpgrades.max_level(id))
    if id==&"speed":
        return tr("TRUCK_STAT_SPEED").format({"a":roundi(19.0*3.6*TruckUpgrades.SPEED_MULTIPLIER[current]),"b":roundi(19.0*3.6*TruckUpgrades.SPEED_MULTIPLIER[next])})
    if id==&"accel":
        return tr("TRUCK_STAT_ACCEL").format({"a":"%.2f" % TruckUpgrades.ACCEL_MULTIPLIER[current],"b":"%.2f" % TruckUpgrades.ACCEL_MULTIPLIER[next]})
    return ""

func refresh() -> void:
    if not is_node_ready(): return
    var state: Dictionary=NetworkSession.truck_state
    _title.text=tr("GARAGE_TITLE")
    _subtitle.text=tr("GARAGE_SUBTITLE")
    _close.text=tr("GARAGE_CLOSE")
    var wallet: int=inventory.coins if is_instance_valid(inventory) else 0
    _coins.text=tr("GARAGE_COINS").format({"n":wallet})
    (_column.get_node("Header0") as Label).text=tr("GARAGE_GROUP_PERF")
    (_column.get_node("Header1") as Label).text=tr("GARAGE_GROUP_BUILD")
    for id in _rows:
        var row: Dictionary=_rows[id]
        var level: int=TruckUpgrades.level(state,id)
        var top: int=TruckUpgrades.max_level(id)
        row.name.text=tr("TRUCK_UP_"+String(id))
        row.description.text=tr("TRUCK_DESC_"+String(id))
        row.stat.text=stat_text(id)
        row.stat.visible=not row.stat.text.is_empty()
        row.pips.text="●".repeat(level)+"○".repeat(top-level) if top>1 else (tr("TRUCK_FITTED") if level>0 else "○")
        var buy: Button=row.buy
        var reason: String=TruckUpgrades.blocker(state,id)
        if reason=="TRUCK_MAXED":
            buy.text=tr("TRUCK_MAXED_BTN") if top>1 else tr("TRUCK_FITTED");buy.disabled=true
        elif reason=="TRUCK_NEEDS":
            buy.text=tr("TRUCK_NEEDS_BTN").format({"item":tr("TRUCK_UP_"+String(TruckUpgrades.requirement(id)))});buy.disabled=true
        else:
            var cost: int=TruckUpgrades.next_cost(state,id)
            buy.text=tr("PRICE").format({"n":cost}) if cost>0 else tr("TRUCK_FREE");buy.disabled=wallet<cost
