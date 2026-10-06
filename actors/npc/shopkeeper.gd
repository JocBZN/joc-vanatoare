class_name Shopkeeper
extends Node3D
## A low-poly crew member of the Mammoth base, built from primitives like the
## rest of the camp. Purely cosmetic and local: every peer sees the keeper turn
## to its own hunter and shout lines at it; nothing here touches the network.

const TALK_RANGE: float=9.0
const BUBBLE_SECONDS: float=4.8
static var _materials: Dictionary={}

@export var npc_id: String="gica"
## "stand" behind a counter, or "lounge" stretched out on a sun bed.
@export var pose: String="stand"
var line_index: int=-1
var talk_count: int=0
var _rng:=RandomNumberGenerator.new()
var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D]=[]
var _bubble: Label3D
var _bubble_back: MeshInstance3D
var _name_tag: Label3D
var _bubble_time: float=0.0
var _cooldown: float=0.0
var _near: bool=false
var _clock: float=0.0
var _rest_yaw: float=0.0

func _ready() -> void:
    _rng.seed=hash(npc_id)^int(Time.get_ticks_usec())
    _clock=_rng.randf()*TAU
    _rest_yaw=rotation.y
    _build(NpcCatalog.entry(npc_id))
    LocaleSettings.changed.connect(_localize)
    _localize()

## Shouts a line; -1 picks a random one that differs from the last.
func say(index: int=-1) -> String:
    if NpcCatalog.line_count(npc_id)==0: return ""
    line_index=index if index>=0 else NpcCatalog.random_line(npc_id,_rng,line_index)
    talk_count+=1
    _bubble_time=BUBBLE_SECONDS
    _cooldown=_rng.randf_range(8.0,13.0)
    _bubble.text=current_line()
    _fit_bubble()
    _bubble.show();_bubble_back.show()
    return _bubble.text

func current_line() -> String:
    return tr(NpcCatalog.line_key(npc_id,line_index)) if line_index>=0 else ""

func display_name() -> String:
    return tr(NpcCatalog.name_key(npc_id))

func is_talking() -> bool:
    return _bubble_time>0.0

func _localize() -> void:
    _name_tag.text=display_name()
    if line_index>=0: _bubble.text=current_line();_fit_bubble()

func _process(delta: float) -> void:
    _clock+=delta
    var hunter=NetworkSession.local_hunter()
    var distance: float=INF
    if is_instance_valid(hunter) and hunter.is_inside_tree(): distance=hunter.global_position.distance_to(global_position)
    if distance<TALK_RANGE:
        if not _near: _near=true;say()
        _cooldown-=delta
        if _cooldown<=0.0 and not is_talking(): say()
    elif distance>TALK_RANGE+2.0: _near=false
    # Turn the whole body toward the hunter; drift back to the counter otherwise.
    var target_yaw: float=_rest_yaw+sin(_clock*.35)*.35
    if _near and pose=="stand":
        var flat: Vector3=hunter.global_position-global_position
        if Vector2(flat.x,flat.z).length()>.2: target_yaw=atan2(flat.x,flat.z)
    if pose=="stand": rotation.y=lerp_angle(rotation.y,target_yaw,clampf(delta*3.0,0,1))
    var talking: bool=is_talking()
    _body.position.y=sin(_clock*1.7)*.012
    _head.rotation.x=sin(_clock*(9.0 if talking else 1.1))*(.09 if talking else .03)
    _head.rotation.z=sin(_clock*.6)*.05
    for side in 2:
        var arm: Node3D=_arms[side]
        var sign_value: float=-1.0 if side==0 else 1.0
        if pose=="lounge": arm.rotation=Vector3(-2.6,0,sign_value*.5)
        elif talking: arm.rotation=Vector3(-.9+sin(_clock*6.0+side*1.7)*.55,0,sign_value*(.25+sin(_clock*4.0)*.15))
        else: arm.rotation=Vector3(sin(_clock*1.3+side)*.06,0,sign_value*.08)
    if talking:
        _bubble_time-=delta
        if _bubble_time<=0.0: _bubble.hide();_bubble_back.hide()

func _build(look: Dictionary) -> void:
    var height: float=float(look.get("height",1.0))
    var belly: float=float(look.get("belly",.2))
    _body=Node3D.new();_body.name="Body";add_child(_body)
    var rig:=Node3D.new();rig.name="Rig";rig.scale=Vector3.ONE*height;_body.add_child(rig)
    var pants: Color=look.get("pants",Color("333333"))
    var shirt: Color=look.get("shirt",Color("777777"))
    var skin: Color=look.get("skin",Color("e0a57a"))
    var hips:=Node3D.new();hips.name="Hips";rig.add_child(hips)
    if pose=="lounge":
        # Stretched out on a sun bed: the whole rig leans back from the heels.
        rig.position.y=.5;rig.rotation.x=-1.32
    for x in [-.13,.13]:
        var leg:=Node3D.new();leg.position=Vector3(x,.86,0);hips.add_child(leg)
        _part(leg,_box(Vector3(.2,.8,.22)),Vector3(0,-.42,0),pants)
        _part(leg,_box(Vector3(.22,.12,.34)),Vector3(0,-.8,.06),Color("2a2420"))
    var torso:=Node3D.new();torso.name="Torso";torso.position=Vector3(0,.86,0);hips.add_child(torso)
    _part(torso,_box(Vector3(.58,.7,.34)),Vector3(0,.36,0),shirt)
    if belly>0: _part(torso,_sphere(.22+belly*.5,7,5),Vector3(0,.26,.1+belly*.3),shirt).scale=Vector3(1.15,.9,.75)
    var apron: Color=look.get("apron",Color())
    if apron.a>0 and apron!=Color(): _part(torso,_box(Vector3(.5,.62,.04)),Vector3(0,.18,.22+belly*.55),apron)
    for side in 2:
        var x: float=-.36 if side==0 else .36
        var shoulder:=Node3D.new();shoulder.position=Vector3(x,.66,0);torso.add_child(shoulder)
        _part(shoulder,_box(Vector3(.16,.58,.18)),Vector3(0,-.28,0),shirt)
        _part(shoulder,_sphere(.085,6,4),Vector3(0,-.62,0),skin)
        _arms.append(shoulder)
    _head=Node3D.new();_head.name="Head";_head.position=Vector3(0,.74,0);torso.add_child(_head)
    _part(_head,_box(Vector3(.12,.1,.12)),Vector3(0,.04,0),skin)
    _part(_head,_sphere(.21,8,6),Vector3(0,.26,0),skin).scale=Vector3(1,1.08,1)
    _part(_head,_box(Vector3(.08,.11,.11)),Vector3(0,.24,.21),skin.darkened(.08))
    for x in [-.075,.075]: _part(_head,_box(Vector3(.045,.05,.02)),Vector3(x,.31,.19),Color("14110f"))
    if look.get("glasses",false):
        for x in [-.075,.075]: _part(_head,_box(Vector3(.09,.075,.015)),Vector3(x,.31,.205),Color("1d1d1f"))
        _part(_head,_box(Vector3(.06,.02,.015)),Vector3(0,.32,.205),Color("1d1d1f"))
    if look.get("mustache",false): _part(_head,_box(Vector3(.2,.05,.05)),Vector3(0,.17,.2),look.get("hair",Color("2a2018")))
    _part(_head,_box(Vector3(.44,.12,.4)),Vector3(0,.42,-.03),look.get("hair",Color("2a2018")))
    var hat_color: Color=look.get("hat_color",Color("444444"))
    match String(look.get("hat","")):
        "cap":
            _part(_head,_box(Vector3(.46,.14,.44)),Vector3(0,.5,0),hat_color)
            _part(_head,_box(Vector3(.4,.03,.22)),Vector3(0,.45,.28),hat_color.darkened(.2))
        "beret": _part(_head,_cylinder(.26,.24,.1,8),Vector3(.04,.5,0),hat_color).rotation.z=.15
        "beanie":
            _part(_head,_cylinder(.24,.22,.22,8),Vector3(0,.52,0),hat_color)
            _part(_head,_sphere(.07,6,4),Vector3(0,.68,0),hat_color.lightened(.3))
        "scarf":
            _part(_head,_sphere(.235,8,6),Vector3(0,.31,-.075),hat_color)
            _part(_head,_box(Vector3(.18,.18,.04)),Vector3(0,.12,-.22),hat_color.darkened(.15))
        "captain":
            _part(_head,_cylinder(.25,.23,.16,10),Vector3(0,.52,0),hat_color)
            _part(_head,_box(Vector3(.4,.03,.2)),Vector3(0,.45,.26),Color("1b2633"))
            _part(_head,_box(Vector3(.1,.06,.02)),Vector3(0,.55,.25),Color("e3b23c"))
    _name_tag=_label(26,Color("f6e3b5"),Vector3(0,2.12*height,0) if pose=="stand" else Vector3(0,1.05,-1.7))
    _name_tag.name="NameTag"
    _bubble=_label(34,Color("fff6dc"),_name_tag.position+Vector3(0,.3,0))
    _bubble.name="Bubble";_bubble.width=520;_bubble.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _bubble.modulate=Color("fff6dc");_bubble.outline_modulate=Color("2b1a10");_bubble.hide()
    _bubble.render_priority=2;_bubble.outline_render_priority=1
    # A dark speech card behind the text keeps it readable over busy walls.
    _bubble_back=MeshInstance3D.new();_bubble_back.name="BubbleCard";_bubble_back.mesh=QuadMesh.new()
    var card:=StandardMaterial3D.new();card.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    card.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;card.albedo_color=Color(.09,.06,.045,.86)
    card.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;card.cull_mode=BaseMaterial3D.CULL_DISABLED;card.render_priority=0
    _bubble_back.material_override=card;_bubble_back.set_meta("styled",true);_bubble_back.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_bubble_back);_bubble_back.hide()

func _fit_bubble() -> void:
    var font: Font=_bubble.font if _bubble.font else ThemeDB.fallback_font
    var size: Vector2=font.get_multiline_string_size(_bubble.text,HORIZONTAL_ALIGNMENT_CENTER,_bubble.width,_bubble.font_size)
    var extent: Vector2=(size+Vector2(46,26))*_bubble.pixel_size
    (_bubble_back.mesh as QuadMesh).size=extent
    _bubble_back.position=_bubble.position+Vector3(0,size.y*_bubble.pixel_size*.5,0)

func _label(size: int, color: Color, at: Vector3) -> Label3D:
    var label:=Label3D.new();label.font_size=size;label.outline_size=10;label.pixel_size=.0052
    label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=at
    label.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;add_child(label)
    return label

func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at
    node.material_override=toon(color);node.set_meta("styled",true)
    parent.add_child(node)
    return node

func _box(size: Vector3) -> BoxMesh:
    var mesh:=BoxMesh.new();mesh.size=size;return mesh

func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
    var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=segments;mesh.rings=rings
    return mesh

func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
    var mesh:=CylinderMesh.new();mesh.top_radius=top;mesh.bottom_radius=bottom;mesh.height=height;mesh.radial_segments=segments
    return mesh

## Flat toon colour shared by every low-poly part of the base and its crew.
static func toon(color: Color, glow: float=0.0) -> StandardMaterial3D:
    var key: String=color.to_html()+str(glow)
    if _materials.has(key): return _materials[key]
    var material:=StandardMaterial3D.new();material.albedo_color=color
    material.roughness=.9;material.metallic_specular=.2;material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
    if glow>0.0: material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=glow
    _materials[key]=material
    return material
