class_name CampMenu
extends CanvasLayer

signal continued
var is_open: bool = true
var started: bool = false
var _network_labels: Dictionary = {}
var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _network_status: Label
var _host: Button
var _join: Button
var _leave: Button
var _return_lobby: Button
var _root: Control
var _title: Label
var _tag: Label
var _description: Label
var _play: Button
var _quit: Button
var _language_label: Label
var _language: OptionButton
var _volume_label: Label
var _volume: HSlider
var _cinematic: CheckButton
var _perspective: OptionButton
var _perspective_label: Label
var _graphics: OptionButton
var _graphics_label: Label
var _weapon_credits: RichTextLabel

func _ready() -> void:
    layer = 20
    _build()
    LocaleSettings.changed.connect(refresh)
    _build_network()
    NetworkSession.changed.connect(refresh)
    refresh()

func _input(event: InputEvent) -> void:
    if is_open and event.is_action_pressed("release_cursor"):
        if started:
            resume()
        get_viewport().set_input_as_handled()

func open() -> void:
    is_open = true
    _root.show()
    refresh()

func resume() -> void:
    started = true
    is_open = false
    _root.hide()
    continued.emit()

func dismiss_for_loading() -> void:
    is_open=false
    _root.hide()

func refresh() -> void:
    if _network_status:
        _network_status.text=NetworkSession.status_text()
        for key in _network_labels: _network_labels[key].text=tr(key)
        _host.text=tr("HOST")
        _join.text=tr("JOIN")
        _leave.text=tr("LEAVE")
        var joining:=NetworkSession.mode=="connecting"
        _host.disabled=joining
        _join.disabled=joining
        _leave.disabled=NetworkSession.mode=="solo"
        _host.disabled=joining or NetworkSession.mode in ["host","client"]
        _join.disabled=joining or NetworkSession.mode in ["host","client"]
        _return_lobby.text=tr("RETURN_LOBBY")
        _return_lobby.visible=NetworkSession.phase=="hunt"
        _return_lobby.disabled=not NetworkSession.is_host() or NetworkSession.phase=="loading"
    _tag.text = tr("MENU_TAG")
    _title.text = tr("MENU_PAUSE" if started else "MENU_TITLE")
    _description.text = tr("MENU_DESC")
    _play.text = tr("RESUME" if started else "PLAY")
    _quit.text = tr("QUIT")
    _language_label.text = tr("LANGUAGE")
    _volume_label.text = tr("VOLUME")
    _language.select(0 if LocaleSettings.language == "en" else 1)
    _perspective_label.text=tr("PERSPECTIVE")
    _perspective.set_item_text(0,tr("THIRD_PERSON"));_perspective.set_item_text(1,tr("FIRST_PERSON"))
    _perspective.select(1 if LocaleSettings.perspective=="first" else 0)
    _graphics_label.text=tr("GRAPHICS")
    for index in 3: _graphics.set_item_text(index,tr(["GRAPHICS_LOW","GRAPHICS_MEDIUM","GRAPHICS_HIGH"][index]))
    _graphics.select(["low","medium","high"].find(LocaleSettings.graphics))
    _cinematic.text = tr("CINEMATIC")
    _cinematic.set_pressed_no_signal(LocaleSettings.cinematic)
    _weapon_credits.text="[center][url=https://sketchfab.com/3d-models/weapon-pack-of-10100-part-1-79f1c9b1d9d146a6adc7837b01bc22e3]Weapon Pack of 10/100 Part 1[/url] · [url=https://sketchfab.com/OburGames]OBUR Games[/url] · [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url] · "+tr("WEAPON_MODELS_ADAPTED")+"[/center]"

func _build() -> void:
    _root = Control.new()
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    _root.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.025, 0.03, 0.38)
    var panel := PanelContainer.new()
    _root.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
    panel.offset_left = 58
    panel.offset_right = 554
    panel.offset_top = -320
    panel.offset_bottom = 320
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.04, 0.065, 0.058, 0.95)
    style.border_color = Color("c19a5e")
    style.border_width_left = 3
    style.set_corner_radius_all(12)
    style.content_margin_left = 32
    style.content_margin_right = 32
    style.content_margin_top = 28
    style.content_margin_bottom = 28
    panel.add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 9)
    panel.add_child(column)
    _tag = _label(13, Color("d9b474"))
    column.add_child(_tag)
    var brand := _label(20, Color("fff0ce"))
    brand.text = "HUNT TOGETHER"
    column.add_child(brand)
    _title = _label(34, Color("fff0ce"))
    column.add_child(_title)
    _description = _label(15, Color("b7c4b4"))
    _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_description)
    column.add_child(HSeparator.new())
    var row := HBoxContainer.new()
    column.add_child(row)
    _language_label = _label(17, Color("e7dcc1"))
    _language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_language_label)
    _language = OptionButton.new()
    _language.custom_minimum_size = Vector2(180, 40)
    _language.add_item("English")
    _language.add_item("Română")
    row.add_child(_language)
    _language.item_selected.connect(func(index: int) -> void: LocaleSettings.set_language("en" if index == 0 else "ro"))
    var view_row:=HBoxContainer.new();column.add_child(view_row)
    _perspective_label=_label(17,Color("e7dcc1"));_perspective_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view_row.add_child(_perspective_label)
    _perspective=OptionButton.new();_perspective.custom_minimum_size=Vector2(180,40)
    _perspective.add_item("");_perspective.add_item("");view_row.add_child(_perspective)
    _perspective.item_selected.connect(func(index: int) -> void: LocaleSettings.set_perspective("first" if index==1 else "third"))
    var graphics_row:=HBoxContainer.new();column.add_child(graphics_row)
    _graphics_label=_label(17,Color("e7dcc1"));_graphics_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;graphics_row.add_child(_graphics_label)
    _graphics=OptionButton.new();_graphics.custom_minimum_size=Vector2(180,40)
    for index in 3: _graphics.add_item("")
    graphics_row.add_child(_graphics)
    _graphics.item_selected.connect(func(index: int) -> void: LocaleSettings.set_graphics(["low","medium","high"][index]))
    _volume_label = _label(16, Color("e7dcc1"))
    column.add_child(_volume_label)
    _volume = HSlider.new()
    _volume.min_value = 0.0
    _volume.max_value = 1.0
    _volume.step = 0.01
    _volume.value = LocaleSettings.sound_volume
    column.add_child(_volume)
    _volume.value_changed.connect(LocaleSettings.set_volume)
    _cinematic = CheckButton.new()
    column.add_child(_cinematic)
    _cinematic.toggled.connect(LocaleSettings.set_cinematic)
    _play = _button(Color("a67c3f"))
    _play.custom_minimum_size.y = 52
    column.add_child(_play)
    _play.pressed.connect(resume)
    _quit = _button(Color("29372d"))
    column.add_child(_quit)
    _quit.pressed.connect(func() -> void: get_tree().quit())
    _weapon_credits=RichTextLabel.new();_root.add_child(_weapon_credits)
    _weapon_credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _weapon_credits.offset_left=58;_weapon_credits.offset_right=-58
    _weapon_credits.offset_top=-30;_weapon_credits.offset_bottom=-7
    _weapon_credits.bbcode_enabled=true;_weapon_credits.scroll_active=false
    _weapon_credits.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
    _weapon_credits.add_theme_font_size_override("normal_font_size",11)
    _weapon_credits.add_theme_color_override("default_color",Color("b7c4b4"))
    _weapon_credits.meta_clicked.connect(func(url: Variant) -> void: OS.shell_open(String(url)))

func _label(size: int, color: Color) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _button(color: Color) -> Button:
    var button := Button.new()
    button.add_theme_font_size_override("font_size", 18)
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.set_corner_radius_all(6)
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = color.lightened(0.18)
    button.add_theme_stylebox_override("hover", hover)
    return button

func _build_network() -> void:
    var panel:=PanelContainer.new()
    _root.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
    panel.offset_left=-620
    panel.offset_right=-58
    panel.offset_top=-306
    panel.offset_bottom=306
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.035,.055,.05,.96)
    style.set_corner_radius_all(12)
    style.content_margin_left=28
    style.content_margin_right=28
    style.content_margin_top=24
    style.content_margin_bottom=24
    panel.add_theme_stylebox_override("panel",style)
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    panel.add_child(column)
    for key in ["NETWORK_TITLE","PLAYER_NAME"]:
        var label:=_label(24 if key=="NETWORK_TITLE" else 15,Color("e7dcc1"))
        _network_labels[key]=label
        column.add_child(label)
    _name=LineEdit.new()
    _name.text="Hunter"
    _name.max_length=24
    _name.custom_minimum_size.y=38
    column.add_child(_name)
    var ip_label:=_label(15,Color("e7dcc1"))
    _network_labels["HOST_IP"]=ip_label
    column.add_child(ip_label)
    var row:=HBoxContainer.new()
    column.add_child(row)
    _address=LineEdit.new()
    _address.text="127.0.0.1"
    _address.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _address.custom_minimum_size.y=38
    row.add_child(_address)
    _port=SpinBox.new()
    _port.min_value=1024
    _port.max_value=65535
    _port.value=24567
    row.add_child(_port)
    _host=_button(Color("766039"))
    column.add_child(_host)
    _host.pressed.connect(func() -> void:
        if NetworkSession.host_game(_name.text,int(_port.value))==OK: resume())
    _join=_button(Color("3c644e"))
    column.add_child(_join)
    _join.pressed.connect(func() -> void: NetworkSession.join_game(_name.text,_address.text,int(_port.value)))
    _leave=_button(Color("29372d"))
    column.add_child(_leave)
    _leave.pressed.connect(NetworkSession.leave_game)
    _return_lobby=_button(Color("a67c3f"))
    column.add_child(_return_lobby)
    _return_lobby.pressed.connect(func() -> void:
        NetworkSession.request_action("return_lobby"))
    _network_status=_label(16,Color("e4be7d"))
    _network_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_network_status)
    var note:=_label(13,Color("b7c4b4"))
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _network_labels["NETWORK_NOTE"]=note
    column.add_child(note)
