extends CanvasLayer
signal closed
var is_open: bool=false
var root_control: Control
var start_button: Button
var close_button: Button
var camp_button: Button
var status: Label
var title: Label
var subtitle: Label
var forest_title: Label
var description: Label
var animal_list: Label
var badge: Label
var message: String=""
var selected: String="forest"
var picture: TextureRect
var map_buttons: Dictionary={}
const DESTINATIONS=["forest","swamp"]

func _ready() -> void:
    layer=15
    _build()
    root_control.hide()
    LocaleSettings.changed.connect(refresh)
    NetworkSession.changed.connect(refresh)
    refresh()

func _input(event: InputEvent) -> void:
    if is_open and event.is_action_pressed("release_cursor"):
        close()
        get_viewport().set_input_as_handled()

func open() -> void:
    is_open=true;message="";refresh();root_control.show()

func close() -> void:
    if not is_open: return
    is_open=false;root_control.hide();closed.emit()

func show_message(value: String) -> void:
    message=value;refresh()

func refresh() -> void:
    if not is_node_ready(): return
    title.text=tr("MAP_TITLE")
    subtitle.text=tr("MAP_SUBTITLE")
    forest_title.text=tr(WorldCatalog.title_key(selected))
    description.text=tr("MAP_SWAMP_DESC" if selected=="swamp" else "MAP_FOREST_DESC")
    animal_list.text=tr("MAP_SWAMP_ANIMALS" if selected=="swamp" else "MAP_ANIMALS")
    for id in map_buttons:
        map_buttons[id].text=tr(WorldCatalog.title_key(id))
        map_buttons[id].button_pressed=id==selected
    var path: String="res://assets/ui/"+selected+"_card.png"
    if ResourceLoader.exists(path): picture.texture=load(path)
    badge.text="%02d / %s" % [DESTINATIONS.find(selected)+1,tr("MAP_READY")]
    close_button.text=tr("MAP_BACK")
    start_button.text=tr("MAP_START" if NetworkSession.is_host() else "WAIT_HOST")
    var hunter=NetworkSession.local_hunter()
    start_button.disabled=not NetworkSession.is_host() or NetworkSession.phase!="lobby" or not hunter or not hunter.world_ready or hunter.health<=0 or (NetworkSession.mode=="host" and NetworkSession.players.size()<NetworkSession.required_players)
    # Out hunting, the driver's map also offers the way home.
    camp_button.text=tr("RETURN_LOBBY")
    camp_button.visible=NetworkSession.phase=="hunt" and NetworkSession.is_host()
    start_button.visible=NetworkSession.phase=="lobby" or not NetworkSession.is_host()
    status.text=message if not message.is_empty() else tr("MAP_HOST_HINT" if NetworkSession.is_host() else "MAP_CLIENT_HINT")

func _build() -> void:
    root_control=Control.new();add_child(root_control)
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade:=ColorRect.new();root_control.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.015,.028,.024,.86)
    var panel:=PanelContainer.new();root_control.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left=-540;panel.offset_right=540;panel.offset_top=-310;panel.offset_bottom=310
    var style:=StyleBoxFlat.new();style.bg_color=Color("14211e");style.set_corner_radius_all(14)
    style.border_color=Color("b79052");style.border_width_top=3
    style.content_margin_left=30;style.content_margin_right=30;style.content_margin_top=24;style.content_margin_bottom=24
    panel.add_theme_stylebox_override("panel",style)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
    title=_label(30,Color("ffe2a9"));column.add_child(title)
    subtitle=_label(16,Color("a9c4b6"));column.add_child(subtitle)
    var selector:=HBoxContainer.new();selector.add_theme_constant_override("separation",12);column.add_child(selector)
    for id in DESTINATIONS:
        var choice:=_button(Color("32483c"));choice.toggle_mode=true;choice.custom_minimum_size=Vector2(180,40)
        selector.add_child(choice);map_buttons[id]=choice
        choice.pressed.connect(func() -> void: select_map(id))
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.custom_minimum_size.y=310;column.add_child(row)
    picture=TextureRect.new();picture.custom_minimum_size=Vector2(570,310)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.clip_contents=true;row.add_child(picture)
    if ResourceLoader.exists("res://assets/ui/forest_card.png"): picture.texture=load("res://assets/ui/forest_card.png")
    var details:=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    details.add_theme_constant_override("separation",16);row.add_child(details)
    badge=_label(13,Color("92d0ab"));details.add_child(badge)
    forest_title=_label(34,Color("f2dcaf"));details.add_child(forest_title)
    description=_label(17,Color("c3d0bf"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(description)
    animal_list=_label(15,Color("9fbeac"));animal_list.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(animal_list)
    var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.add_child(spacer)
    start_button=_button(Color("9d773e"));start_button.custom_minimum_size.y=54;details.add_child(start_button)
    start_button.pressed.connect(func() -> void: NetworkSession.request_action("start_hunt",selected))
    camp_button=_button(Color("5e4a2c"));camp_button.custom_minimum_size.y=54;details.add_child(camp_button)
    camp_button.pressed.connect(func() -> void: NetworkSession.request_action("return_lobby"))
    status=_label(15,Color("d9bd83"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
    close_button=_button(Color("293b32"));close_button.custom_minimum_size.y=42;column.add_child(close_button)
    close_button.pressed.connect(close)

func select_map(id: String) -> void:
    if id not in DESTINATIONS: return
    selected=id;message="";refresh()

func _label(size: int,color: Color) -> Label:
    var label:=Label.new();label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
    label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
    return label

func _button(color: Color) -> Button:
    var button:=Button.new();button.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED;button.add_theme_font_size_override("font_size",17)
    var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(6)
    button.add_theme_stylebox_override("normal",style)
    var hover:=style.duplicate() as StyleBoxFlat;hover.bg_color=color.lightened(.14);button.add_theme_stylebox_override("hover",hover)
    return button
