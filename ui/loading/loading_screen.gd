class_name LoadingScreen
extends CanvasLayer
var root_control: Control
var title: Label
var map_label: Label
var team_label: Label
var tip: Label
var percent: Label
var bar: ProgressBar
var cancel: Button
var value: float=0.0
var target: String="forest"

func _ready() -> void:
    layer=40
    root_control=Control.new();add_child(root_control)
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background:=ColorRect.new();root_control.add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color=Color("071416")
    var stripe:=ColorRect.new();root_control.add_child(stripe)
    stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    stripe.offset_bottom=4;stripe.color=Color("d9ab62")
    var container:=VBoxContainer.new();root_control.add_child(container)
    container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    container.offset_left=-380;container.offset_right=380
    container.offset_top=-190;container.offset_bottom=190
    container.add_theme_constant_override("separation",18)
    var brand:=label("HUNT TOGETHER  /  CO-OP",16,Color("91bdb0"));container.add_child(brand)
    title=label("",36,Color("ffe3ad"));container.add_child(title)
    map_label=label("",20,Color("c4d4c5"));container.add_child(map_label)
    bar=ProgressBar.new();bar.custom_minimum_size.y=14
    bar.show_percentage=false
    var fill:=StyleBoxFlat.new();fill.bg_color=Color("d2a354");fill.set_corner_radius_all(4)
    var base:=StyleBoxFlat.new();base.bg_color=Color("203634");base.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("fill",fill);bar.add_theme_stylebox_override("background",base)
    container.add_child(bar)
    percent=label("",16,Color("e5c17e"));container.add_child(percent)
    team_label=label("",18,Color("95ccba"));container.add_child(team_label)
    tip=label("",16,Color("a4b9ad"));tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    container.add_child(tip)
    cancel=Button.new();cancel.custom_minimum_size.y=42;container.add_child(cancel)
    cancel.pressed.connect(func() -> void: NetworkSession.request_action("cancel_loading"))
    root_control.hide()
    LocaleSettings.changed.connect(refresh)
    NetworkSession.changed.connect(refresh)

func label(text: String,size: int,color: Color) -> Label:
    var result:=Label.new();result.text=text
    result.add_theme_font_size_override("font_size",size)
    result.add_theme_color_override("font_color",color)
    return result

## The cover is opaque, so the 3D world behind it is not drawn while a map is
## being built: on a weak GPU that frame time goes to the build instead.
func begin(id: String) -> void:
    target=id;value=0;root_control.show();refresh()
    get_viewport().disable_3d=true

func update_progress(amount: float) -> void:
    value=maxf(value,clampf(amount,0,1))
    refresh()

func finish() -> void:
    root_control.hide()
    get_viewport().disable_3d=false

func refresh() -> void:
    if not is_node_ready(): return
    title.text=tr("LOADING_TITLE" if WorldCatalog.is_hunt(target) else "LOADING_RETURN")
    map_label.text=tr("LOADING_WAIT") if value>=1 else LocaleSettings.text("LOADING_MAP",{"name":tr(WorldCatalog.name_key(target))})
    bar.value=value*100
    percent.text="%d%%" % roundi(value*100)
    team_label.text=LocaleSettings.text("LOADING_TEAM",{"ready":NetworkSession.ready_players.size(),"total":NetworkSession.loading_members.size()})
    tip.text=tr("LOADING_TIP")
    cancel.text=tr("LOADING_CANCEL")
    cancel.visible=NetworkSession.is_host() and WorldCatalog.is_hunt(target)
