extends Control
## The maps. Top right, a round radar that turns with the camera and paints the
## real relief under you (hills, contour lines, water, the road); it zooms out
## while driving and keeps the truck, your friends and nearby bosses pinned to
## its rim when they are out of range. M opens the whole map, north up, with a
## pictogram for every animal, a crown over each boss, the party, the truck and
## the trophies, plus a legend. Reads replicated state only: no networking.

const Icons:=preload("res://ui/hud/map_icons.gd")
const Paint:=preload("res://ui/hud/hud_paint.gd")
const RELIEF:=preload("res://ui/hud/map_relief.gdshader")
const RADAR_SIZE: float=168.0
const RADAR_MARGIN: float=18.0
const FOOT_RANGE: float=105.0
const DRIVE_RANGE: float=240.0
## Bosses further than this stay off the radar rim; the big map always shows them.
const BOSS_HINT_RANGE: float=650.0

var detail: bool=false
## Big map zoom (1 = whole map); zoomed in, the view follows you.
var full_zoom: float=1.0
var _full_center:=Vector2.ZERO
var radar: ColorRect
var radar_icons: Control
var full_root: Control
var full_map: ColorRect
var full_icons: Control
var heights_texture: ImageTexture
var _relief_id: int=0
var _range: float=FOOT_RANGE
var _turn: float=0.0
var _center:=Vector2.ZERO
var _clock: float=0.0

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    radar=_relief_rect()
    radar.anchor_left=1.0;radar.anchor_right=1.0
    radar.offset_left=-RADAR_SIZE-RADAR_MARGIN;radar.offset_right=-RADAR_MARGIN
    radar.offset_top=RADAR_MARGIN;radar.offset_bottom=RADAR_MARGIN+RADAR_SIZE
    add_child(radar)
    radar_icons=Control.new();radar_icons.mouse_filter=Control.MOUSE_FILTER_IGNORE
    radar_icons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);radar.add_child(radar_icons)
    radar_icons.draw.connect(_draw_radar)
    full_root=Control.new();full_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    full_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);full_root.hide();add_child(full_root)
    var shade:=ColorRect.new();shade.color=Color(0.02,0.03,0.03,0.74);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);full_root.add_child(shade)
    full_map=_relief_rect();full_root.add_child(full_map)
    var material: ShaderMaterial=full_map.material
    material.set_shader_parameter("circle",false);material.set_shader_parameter("corner",.018)
    material.set_shader_parameter("grid",200.0);material.set_shader_parameter("opacity",1.0)
    full_icons=Control.new();full_icons.mouse_filter=Control.MOUSE_FILTER_IGNORE
    full_icons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);full_root.add_child(full_icons)
    full_icons.draw.connect(_draw_full)

func _relief_rect() -> ColorRect:
    var rect:=ColorRect.new();rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var material:=ShaderMaterial.new();material.shader=RELIEF;rect.material=material
    return rect

func toggle_detail() -> void:
    detail=not detail

func close_detail() -> void:
    detail=false

## Mouse wheel on the big map: 1x, 2x, 4x, 8x.
func zoom_full(step: int) -> void:
    full_zoom=clampf(full_zoom*(2.0 if step>0 else .5),1.0,8.0)

## The terrain texture: the map's own height grid, uploaded once per map.
func _ensure_relief(map) -> bool:
    if not is_instance_valid(map) or not ("heights" in map) or map.heights.is_empty(): return false
    if _relief_id==map.get_instance_id() and heights_texture: return true
    var count: int=map.CELLS+1
    var image:=Image.create_from_data(count,count,false,Image.FORMAT_RF,map.heights.to_byte_array())
    heights_texture=ImageTexture.create_from_image(image)
    _relief_id=map.get_instance_id()
    var swamp: bool=map.has_method("mud_factor")
    for rect in [radar,full_map]:
        var material: ShaderMaterial=rect.material
        material.set_shader_parameter("heights",heights_texture)
        material.set_shader_parameter("cells",float(map.CELLS))
        material.set_shader_parameter("map_size",float(map.SIZE))
        material.set_shader_parameter("swamp",1.0 if swamp else 0.0)
        if swamp:
            var walks:=PackedVector4Array()
            for segment in map.WALKS: walks.append(Vector4(segment[0].x,segment[0].y,segment[1].x,segment[1].y))
            material.set_shader_parameter("walks",walks);material.set_shader_parameter("walk_count",walks.size())
            material.set_shader_parameter("water_level",float(map.WATER_LEVEL))
        else:
            material.set_shader_parameter("walk_count",0)
            material.set_shader_parameter("lake_center",map.LAKE_CENTER)
            material.set_shader_parameter("lake_reach",float(map.LAKE_RADIUS+map.LAKE_SHORE))
            material.set_shader_parameter("lake_level",float(map.LAKE_LEVEL))
    return true

func _process(delta: float) -> void:
    _clock+=delta
    var hunter=NetworkSession.local_hunter()
    var map=NetworkSession.forest
    var live: bool=visible and is_instance_valid(hunter) and WorldCatalog.is_hunt(NetworkSession.world_id) and _ensure_relief(map)
    radar.visible=live and not detail
    full_root.visible=live and detail
    if not live: return
    var camera:=get_viewport().get_camera_3d()
    var forward: Vector3=-camera.global_basis.z if camera else Vector3.FORWARD
    _turn=atan2(-forward.x,-forward.z)
    var driving: bool=hunter.seat_index==0 and is_instance_valid(NetworkSession.jeep)
    var wanted: float=lerpf(FOOT_RANGE*1.3,DRIVE_RANGE,clampf(absf(NetworkSession.jeep.speed)/14.0,0.0,1.0)) if driving else FOOT_RANGE
    _range=lerpf(_range,wanted,1.0-exp(-2.0*delta))
    _center=Vector2(hunter.global_position.x,hunter.global_position.z)
    var material: ShaderMaterial=radar.material
    material.set_shader_parameter("view_center",_center)
    material.set_shader_parameter("view_span",_range*2.0)
    material.set_shader_parameter("view_turn",_turn)
    if detail:
        var frame: Rect2=_full_frame()
        full_map.position=frame.position;full_map.size=frame.size
        var big: ShaderMaterial=full_map.material
        var span: float=float(map.SIZE)/full_zoom
        var limit: float=float(map.SIZE)*.5-span*.5
        _full_center=Vector2(clampf(_center.x,-limit,limit),clampf(_center.y,-limit,limit))
        big.set_shader_parameter("view_center",_full_center)
        big.set_shader_parameter("view_span",span)
        big.set_shader_parameter("view_turn",0.0)
        full_icons.queue_redraw()
    else:
        radar_icons.queue_redraw()

# --- Radar ------------------------------------------------------------------------

func _to_radar(point: Vector3) -> Vector2:
    var offset:=Vector2(point.x,point.z)-_center
    var c: float=cos(_turn);var s: float=sin(_turn)
    var local:=Vector2(offset.x*c-offset.y*s,offset.x*s+offset.y*c)/(_range*2.0)
    return Vector2.ONE*RADAR_SIZE*.5+local*RADAR_SIZE

## Screen turn of something facing `yaw` in the world, on the turning radar.
func _radar_turn(yaw: float) -> float:
    return _turn-yaw

## Position on the radar; things beyond the rim are pinned to it.
func _pin(point: Vector3, inset: float) -> Dictionary:
    var at: Vector2=_to_radar(point)
    var middle:=Vector2.ONE*RADAR_SIZE*.5
    var limit: float=RADAR_SIZE*.5-inset
    var outside: bool=at.distance_to(middle)>limit
    if outside: at=middle+(at-middle).normalized()*limit
    return {"at":at,"outside":outside}

func _draw_radar() -> void:
    var hunter=NetworkSession.local_hunter()
    if not is_instance_valid(hunter): return
    var canvas: Control=radar_icons
    var middle:=Vector2.ONE*RADAR_SIZE*.5
    var radius: float=RADAR_SIZE*.5
    # View cone.
    canvas.draw_colored_polygon(PackedVector2Array([middle,middle+Vector2(-radius*.5,-radius*.92),middle+Vector2(radius*.5,-radius*.92)]),Color(1,1,0.85,0.09))
    # Loot and trophies in range.
    for pickup in NetworkSession.loot.values():
        if not is_instance_valid(pickup): continue
        var place: Dictionary=_pin(pickup.global_position,6)
        if place.outside: continue
        var trophy: bool=pickup.get("trophy")==true
        var size: float=5.0 if trophy else 3.0
        canvas.draw_colored_polygon(PackedVector2Array([place.at+Vector2(0,-size),place.at+Vector2(size,0),place.at+Vector2(0,size),place.at+Vector2(-size,0)]),Icons.GOLD if trophy else Color(1,0.93,0.7,0.8))
    # Wildlife: dots, corpses as crosses, bosses as crowns (pinned to the rim when near).
    for animal in NetworkSession.animals.values():
        if not is_instance_valid(animal) or animal.definition==null: continue
        if animal.definition.boss and not animal.dead:
            if animal.global_position.distance_to(hunter.global_position)>BOSS_HINT_RANGE: continue
            var boss_place: Dictionary=_pin(animal.global_position,10)
            Icons.draw_crown(canvas,boss_place.at,15.0 if not boss_place.outside else 12.0)
            continue
        var place: Dictionary=_pin(animal.global_position,4)
        if place.outside: continue
        if animal.dead:
            if animal.harvested: continue
            var cross: float=3.0
            canvas.draw_line(place.at+Vector2(-cross,-cross),place.at+Vector2(cross,cross),Color(0.92,0.9,0.85,0.85),1.6,true)
            canvas.draw_line(place.at+Vector2(cross,-cross),place.at+Vector2(-cross,cross),Color(0.92,0.9,0.85,0.85),1.6,true)
            continue
        var color: Color=Icons.AGGRESSIVE if animal.definition.aggressive else Icons.PASSIVE.lightened(.25)
        canvas.draw_circle(place.at,4.2,Color(0,0,0,0.5))
        canvas.draw_circle(place.at,3.2,color)
    # The truck: always on the radar, pinned to the rim when far.
    var truck=NetworkSession.jeep
    if is_instance_valid(truck) and hunter.seat_index!=0:
        var truck_place: Dictionary=_pin(truck.global_position,11)
        Icons.draw_truck(canvas,truck_place.at,15.0 if not truck_place.outside else 12.0,_radar_turn(truck.global_rotation.y))
    # Friends: blue arrows, pinned to the rim when far.
    for peer in NetworkSession.players:
        var friend=NetworkSession.players[peer]
        if friend==hunter or not is_instance_valid(friend) or not friend.world_ready: continue
        var friend_place: Dictionary=_pin(friend.global_position,8)
        if friend.health<=0: Paint.skull(canvas,friend_place.at,11.0,Color("ff8b71"))
        else: Icons.draw_arrow(canvas,friend_place.at,11.0 if not friend_place.outside else 9.0,_radar_turn(friend.visual.global_rotation.y),Icons.PARTY)
    # You, in the middle, facing where your body faces.
    var own_yaw: float=truck.global_rotation.y if hunter.seat_index==0 and is_instance_valid(truck) else hunter.visual.global_rotation.y
    if hunter.seat_index==0 and is_instance_valid(truck): Icons.draw_truck(canvas,middle,16.0,_radar_turn(own_yaw))
    else: Icons.draw_arrow(canvas,middle,15.0,_radar_turn(own_yaw),Icons.SELF)
    # Rim and compass.
    canvas.draw_arc(middle,radius-1.0,0,TAU,96,Color(0,0,0,0.45),3.0,true)
    canvas.draw_arc(middle,radius-1.5,0,TAU,96,Color(1,1,1,0.75),1.4,true)
    var c: float=cos(_turn);var s: float=sin(_turn)
    var letters: Array=[["N",Vector2(s,-c)],["E",Vector2(c,s)],["S",Vector2(-s,c)],["W",Vector2(-c,-s)]]
    for letter in letters:
        var at: Vector2=middle+Vector2(letter[1])*(radius-11.0)
        if letter[0]=="N":
            canvas.draw_circle(at,8.5,Color("d9482f"))
            Paint.text(canvas,at+Vector2(-8,4.5),"N",12,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,16,0)
        else:
            Paint.text(canvas,at+Vector2(-8,4.5),tr("COMPASS_"+String(letter[0])),11,Color(1,1,1,0.8),HORIZONTAL_ALIGNMENT_CENTER,16,3)
    # Under the radar: where you are and how far the truck is.
    var label: String=tr(WorldCatalog.name_key(NetworkSession.world_id))
    if is_instance_valid(truck) and hunter.seat_index!=0:
        var gap: float=truck.global_position.distance_to(hunter.global_position)
        if gap>25.0: label+="   ·   "+LocaleSettings.text("MAP_TRUCK_DISTANCE",{"n":_distance_text(gap)})
    var width: float=Paint.text_width(label,12)+22.0
    var pill:=Rect2(Vector2(middle.x-width*.5,RADAR_SIZE+8.0),Vector2(width,22))
    Paint.panel(canvas,pill,Paint.PANEL,11.0)
    Paint.text(canvas,Vector2(pill.position.x,pill.position.y+15.5),label,12,Paint.TEXT,HORIZONTAL_ALIGNMENT_CENTER,width,0)
    Paint.text(canvas,Vector2(middle.x-60,RADAR_SIZE+46.0),tr("MINIMAP_HINT"),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_CENTER,120,3)

func _distance_text(metres: float) -> String:
    return "%.1f km" % (metres/1000.0) if metres>=1000.0 else "%d m" % int(round(metres/5.0)*5)

# --- Big map --------------------------------------------------------------------

const LEGEND_WIDTH: float=250.0

## The map square plus the legend beside it, centred on screen.
func _full_frame() -> Rect2:
    var screen: Vector2=get_viewport_rect().size
    var side: float=minf(screen.y-96.0,screen.x-LEGEND_WIDTH-110.0)
    var left: float=(screen.x-(side+18.0+LEGEND_WIDTH))*.5
    return Rect2(Vector2(left,(screen.y-side)*.5),Vector2(side,side))

## World point on the big map; `span` is how many metres the frame shows.
func _to_full(point: Vector3, frame: Rect2, span: float) -> Vector2:
    return frame.position+((Vector2(point.x,point.z)-_full_center)/span+Vector2(.5,.5))*frame.size

## Big map names, drawn after the icons, most important first: a name that would
## cover one already drawn is left out (zoom in to read it).
func _draw_labels(canvas: Control, labels: Array) -> void:
    labels.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0])<int(b[0]))
    var taken: Array[Rect2]=[]
    for label in labels:
        var value: String=label[2]
        var width: float=Paint.text_width(value,11)
        var box:=Rect2(label[1]+Vector2(-width*.5-3.0,-12.0),Vector2(width+6.0,16.0))
        if taken.any(func(other: Rect2) -> bool: return other.intersects(box)): continue
        taken.append(box)
        Paint.text(canvas,label[1]+Vector2(-width*.5,0),value,11,label[3],HORIZONTAL_ALIGNMENT_LEFT,-1,4)

func _draw_full() -> void:
    var hunter=NetworkSession.local_hunter()
    var map=NetworkSession.forest
    if not is_instance_valid(hunter) or not is_instance_valid(map): return
    var canvas: Control=full_icons
    var frame: Rect2=_full_frame()
    var size: float=float(map.SIZE)/full_zoom
    var inside: Rect2=frame.grow(-4.0)
    # [priority, baseline centre, text, colour]: you, friends, truck, places.
    var labels: Array=[]
    # Places worth a name.
    var places: Array=[]
    if map.has_method("mud_factor"):
        places=[["SWAMP_LANDING",Vector3(0,0,10)],["SWAMP_HUT",Vector3(110,0,-155)],["SWAMP_TOWER",Vector3(-155,0,-100)],["SWAMP_LAIR",Vector3(170,0,-330)]]
    else:
        places=[["SWAMP_LANDING",Vector3(0,0,10)],["MAP_LAKE",Vector3(map.LAKE_CENTER.x,0,map.LAKE_CENTER.y)]]
    for place in places:
        var at: Vector2=_to_full(place[1],frame,size)
        if not inside.has_point(at): continue
        canvas.draw_circle(at,3.0,Color(1,1,1,0.8))
        labels.append([3,at+Vector2(0,18),tr(place[0]),Color(1,0.97,0.88,0.92)])
    # Loot: trophies glow gold.
    for pickup in NetworkSession.loot.values():
        if not is_instance_valid(pickup): continue
        var at: Vector2=_to_full(pickup.global_position,frame,size)
        if not inside.has_point(at): continue
        var trophy: bool=pickup.get("trophy")==true
        var r: float=5.5 if trophy else 3.0
        if trophy: canvas.draw_circle(at,9.0+sin(_clock*4.0)*1.5,Color(1,0.8,0.3,0.25))
        canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,0),at+Vector2(0,r),at+Vector2(-r,0)]),Icons.GOLD if trophy else Color(1,0.93,0.7,0.85))
    # Every animal: a pictogram badge; bosses bigger, with a crown.
    var bosses: Array=[]
    for animal in NetworkSession.animals.values():
        if not is_instance_valid(animal) or animal.definition==null: continue
        if animal.dead and (animal.harvested or not animal.definition.boss): continue
        if animal.definition.boss and not animal.dead: bosses.append(animal);continue
        var spot: Vector2=_to_full(animal.global_position,frame,size)
        if not inside.has_point(spot): continue
        var grow: float=minf(1.6,1.0+(full_zoom-1.0)*.15)
        Icons.draw_badge(canvas,animal.definition,spot,(8.0 if animal.definition.aggressive else 7.0)*grow,animal.dead)
    for boss in bosses:
        var at: Vector2=_to_full(boss.global_position,frame,size)
        if not inside.has_point(at): continue
        canvas.draw_circle(at,18.0+sin(_clock*3.0)*2.0,Color(1,0.75,0.2,0.22))
        Icons.draw_badge(canvas,boss.definition,at,12.5)
    # The truck and the party.
    var truck=NetworkSession.jeep
    if is_instance_valid(truck):
        var at: Vector2=_to_full(truck.global_position,frame,size)
        if inside.has_point(at):
            Icons.draw_truck(canvas,at,20.0,-truck.global_rotation.y)
            labels.append([2,at+Vector2(0,-16),tr("MAP_TRUCK"),Color(1,0.95,0.8)])
    for peer in NetworkSession.players:
        var friend=NetworkSession.players[peer]
        if not is_instance_valid(friend) or not friend.world_ready or friend.seat_index==0: continue
        var at: Vector2=_to_full(friend.global_position,frame,size)
        if not inside.has_point(at): continue
        var me: bool=friend==hunter
        if me: canvas.draw_arc(at,11.0+fmod(_clock*10.0,8.0),0,TAU,32,Color(1,0.95,0.75,1.0-fmod(_clock*10.0,8.0)/8.0),2.0,true)
        if friend.health<=0: Paint.skull(canvas,at,13.0,Color("ff8b71"))
        else: Icons.draw_arrow(canvas,at,15.0 if me else 12.0,-friend.visual.global_rotation.y,Icons.SELF if me else Icons.PARTY)
        labels.append([0 if me else 1,at+Vector2(0,20),tr("MAP_YOU") if me else friend.player_name,Icons.SELF if me else Icons.PARTY.lightened(.3)])
    _draw_labels(canvas,labels)
    # Frame, compass and scale.
    var compass: Vector2=frame.position+Vector2(frame.size.x-26,26)
    canvas.draw_circle(compass,15.0,Color(0,0,0,0.45))
    canvas.draw_colored_polygon(PackedVector2Array([compass+Vector2(0,-12),compass+Vector2(5,0),compass+Vector2(-5,0)]),Color("ff5a3c"))
    canvas.draw_colored_polygon(PackedVector2Array([compass+Vector2(0,12),compass+Vector2(5,0),compass+Vector2(-5,0)]),Color(1,1,1,0.85))
    Paint.text(canvas,compass+Vector2(-10,-17),"N",12,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,20,3)
    var metres: float=50.0
    for nice in [100.0,200.0,250.0,500.0]:
        if nice<=size*.22: metres=nice
    var bar_width: float=frame.size.x*metres/size
    var bar_at: Vector2=frame.position+Vector2(16,frame.size.y-18)
    Paint.panel(canvas,Rect2(bar_at-Vector2(8,22),Vector2(bar_width+16,32)),Paint.PANEL,8.0)
    canvas.draw_line(bar_at,bar_at+Vector2(bar_width,0),Color.WHITE,2.0)
    for x in [0.0,bar_width*.5,bar_width]: canvas.draw_line(bar_at+Vector2(x,-5),bar_at+Vector2(x,1),Color.WHITE,2.0)
    Paint.text(canvas,bar_at+Vector2(0,-8),"%d m" % int(metres),11,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,bar_width,0)
    if full_zoom>1.0: Paint.text(canvas,frame.position+Vector2(14,24),"%d×" % int(full_zoom),13,Paint.ACCENT,HORIZONTAL_ALIGNMENT_LEFT,-1,4)
    _draw_legend(canvas,frame)

## The legend: what lives here (with live counts), the bosses and the keys.
func _draw_legend(canvas: Control, frame: Rect2) -> void:
    var box:=Rect2(Vector2(frame.end.x+18.0,frame.position.y),Vector2(LEGEND_WIDTH,frame.size.y))
    Paint.panel(canvas,box,Paint.PANEL_SOLID,14.0)
    var x: float=box.position.x+18.0
    var y: float=box.position.y+34.0
    var title: String=tr(WorldCatalog.name_key(NetworkSession.world_id))
    Paint.text(canvas,Vector2(x,y),title,Paint.fit_size(title,20,LEGEND_WIDTH-36.0,14),Paint.ACCENT,HORIZONTAL_ALIGNMENT_LEFT,LEGEND_WIDTH-36.0,0)
    y+=22.0
    Paint.text(canvas,Vector2(x,y),tr("MAP_SUBTITLE"),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,LEGEND_WIDTH-36.0,0)
    y+=26.0
    var counts: Dictionary={}
    var boss_alive: Dictionary={}
    for animal in NetworkSession.animals.values():
        if not is_instance_valid(animal) or animal.definition==null or animal.dead: continue
        counts[animal.definition.id]=int(counts.get(animal.definition.id,0))+1
    Paint.text(canvas,Vector2(x,y),tr("MAP_LEGEND_ANIMALS").to_upper(),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=20.0
    for entry: AnimalDefinition in AnimalCatalog.population(NetworkSession.world_id):
        Icons.draw_badge(canvas,entry,Vector2(x+10,y-4),9.0)
        Paint.text(canvas,Vector2(x+28,y+1),tr(entry.display_name),13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,LEGEND_WIDTH-100.0,0)
        Paint.text(canvas,Vector2(box.end.x-56,y+1),str(int(counts.get(entry.id,0))),13,Paint.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,38,0)
        y+=25.0
    y+=8.0
    Paint.text(canvas,Vector2(x,y),tr("MAP_LEGEND_BOSSES").to_upper(),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=26.0
    var boss: AnimalDefinition=AnimalCatalog.boss_for(NetworkSession.world_id)
    var alive: int=int(counts.get(boss.id,0))
    Icons.draw_badge(canvas,boss,Vector2(x+12,y-2),11.0)
    # Long boss names (the albino crocodile) take two lines.
    for line in Paint.wrap(tr(boss.display_name),13,LEGEND_WIDTH-70.0):
        Paint.text(canvas,Vector2(x+32,y-3),line,13,Icons.GOLD,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
        y+=16.0
    Paint.text(canvas,Vector2(x+32,y-3),LocaleSettings.text("MAP_BOSS_COUNT",{"n":alive,"max":NetworkSession.MAX_BOSSES}),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,LEGEND_WIDTH-70.0,0)
    y+=24.0
    Paint.text(canvas,Vector2(x,y),tr("MAP_LEGEND_OTHER").to_upper(),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=22.0
    Icons.draw_arrow(canvas,Vector2(x+10,y-4),13.0,0.0,Icons.SELF)
    Paint.text(canvas,Vector2(x+28,y+1),tr("MAP_YOU"),13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=24.0
    Icons.draw_arrow(canvas,Vector2(x+10,y-4),11.0,0.0,Icons.PARTY)
    Paint.text(canvas,Vector2(x+28,y+1),tr("MAP_PARTY"),13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=24.0
    Icons.draw_truck(canvas,Vector2(x+10,y-4),16.0,0.0)
    Paint.text(canvas,Vector2(x+28,y+1),tr("MAP_TRUCK"),13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    y+=24.0
    var r: float=5.0
    var at:=Vector2(x+10,y-4)
    canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,0),at+Vector2(0,r),at+Vector2(-r,0)]),Icons.GOLD)
    Paint.text(canvas,Vector2(x+28,y+1),tr("MAP_TROPHY"),13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,0)
    Paint.text(canvas,Vector2(x,box.end.y-18.0),tr("MINIMAP_CLOSE_HINT"),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,LEGEND_WIDTH-36.0,0)
