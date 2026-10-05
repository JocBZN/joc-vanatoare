extends Control
## Always-on round radar, top-right. M swaps it for a bigger whole-map overview.
## Both read already-replicated client state (NetworkSession.animals/players); no new networking.

var detail: bool = false

const RADAR_MARGIN: float = 24.0
const RADAR_RADIUS: float = 78.0
const RADAR_TOP: float = 178.0
const RADAR_RANGE_M: float = 85.0
const DETAIL_MARGIN: float = 90.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func toggle_detail() -> void:
    detail = not detail
    queue_redraw()

func close_detail() -> void:
    if detail:
        detail = false
        queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    if not visible: return
    var hunter=NetworkSession.local_hunter()
    if not is_instance_valid(hunter) or not WorldCatalog.is_hunt(NetworkSession.world_id): return
    if detail: _draw_detail(hunter)
    else: _draw_radar(hunter)

func _draw_radar(hunter) -> void:
    var center:=Vector2(size.x-RADAR_MARGIN-RADAR_RADIUS,RADAR_TOP+RADAR_RADIUS)
    draw_circle(center,RADAR_RADIUS,Color(0.04,0.06,0.045,0.82))
    draw_arc(center,RADAR_RADIUS*.5,0,TAU,48,Color(0.3,0.38,0.3,0.4),1.0,true)
    var scale_px: float=RADAR_RADIUS/RADAR_RANGE_M
    var origin: Vector3=hunter.global_position
    for a in NetworkSession.animals.values():
        if not is_instance_valid(a) or a.dead: continue
        _dot(center,origin,a.global_position,scale_px,RADAR_RADIUS-5,Color("e0694a") if a.definition.aggressive else Color("9fd49a"),3.2)
    for peer in NetworkSession.players:
        var p=NetworkSession.players[peer]
        if p==hunter or not is_instance_valid(p) or p.health<=0: continue
        _dot(center,origin,p.global_position,scale_px,RADAR_RADIUS-5,Color("7fb8e8"),3.6)
    _player_arrow(center,hunter,9.0)
    draw_arc(center,RADAR_RADIUS,0,TAU,64,Color(0.8,0.63,0.36,0.85),2.0,true)
    var font:=ThemeDB.fallback_font
    draw_string(font,center+Vector2(-4,-RADAR_RADIUS-8),"N",HORIZONTAL_ALIGNMENT_CENTER,-1,13,Color(0.85,0.84,0.7,0.9))
    draw_string(font,Vector2(center.x-54,RADAR_TOP+RADAR_RADIUS*2+18),tr("MINIMAP_HINT"),HORIZONTAL_ALIGNMENT_CENTER,108,11,Color(0.72,0.76,0.64,0.75))

func _draw_detail(hunter) -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.03,0.025,0.55))
    var radius: float=minf(size.x,size.y)*.5-DETAIL_MARGIN
    var center:=size*.5
    var world_half: float=ForestMap.SIZE*.5
    var scale_px: float=radius/world_half
    var biome: Color=Color(0.1,0.2,0.14,0.92) if NetworkSession.world_id=="swamp" else Color(0.08,0.17,0.1,0.92)
    draw_circle(center,radius,biome)
    for ring in [radius*.33,radius*.66,radius]:
        draw_arc(center,ring,0,TAU,72,Color(0.5,0.6,0.5,0.22),1.0,true)
    for angle_i in 4:
        var angle: float=angle_i*PI*.5
        draw_line(center,center+Vector2.from_angle(angle)*radius,Color(0.5,0.6,0.5,0.18),1.0)
    for a in NetworkSession.animals.values():
        if not is_instance_valid(a) or a.dead: continue
        _dot(center,Vector3.ZERO,a.global_position,scale_px,radius-4,Color("e0694a") if a.definition.aggressive else Color("9fd49a"),4.4)
    for peer in NetworkSession.players:
        var p=NetworkSession.players[peer]
        if p==hunter or not is_instance_valid(p) or p.health<=0: continue
        _dot(center,Vector3.ZERO,p.global_position,scale_px,radius-4,Color("7fb8e8"),5.0)
    _player_arrow(center+Vector2(hunter.global_position.x,hunter.global_position.z)*scale_px,hunter,12.0)
    draw_arc(center,radius,0,TAU,96,Color(0.8,0.63,0.36,0.9),3.0,true)
    var font:=ThemeDB.fallback_font
    draw_string(font,center+Vector2(-60,-radius-20),tr(WorldCatalog.name_key(NetworkSession.world_id)),HORIZONTAL_ALIGNMENT_CENTER,120,20,Color(0.95,0.85,0.65,1))
    draw_string(font,Vector2(center.x-120,center.y+radius+34),tr("MINIMAP_CLOSE_HINT"),HORIZONTAL_ALIGNMENT_CENTER,240,13,Color(0.78,0.81,0.68,0.85))

func _dot(center: Vector2,origin: Vector3,world_pos: Vector3,scale_px: float,clip_radius: float,color: Color,dot_radius: float) -> void:
    var offset:=Vector2(world_pos.x-origin.x,world_pos.z-origin.z)*scale_px
    if offset.length()>clip_radius: return
    draw_circle(center+offset,dot_radius,color)

func _player_arrow(at: Vector2,hunter,scale_amount: float) -> void:
    var heading: float=hunter.visual.rotation.y if is_instance_valid(hunter.visual) else 0.0
    var forward:=Vector2(0,-1).rotated(heading)
    var side:=forward.orthogonal()
    var tip: Vector2=at+forward*scale_amount
    var left: Vector2=at-forward*scale_amount*.55+side*scale_amount*.6
    var right: Vector2=at-forward*scale_amount*.55-side*scale_amount*.6
    draw_colored_polygon(PackedVector2Array([tip,left,right]),Color(0.98,0.85,0.4,1))
