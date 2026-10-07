class_name OceanMap
extends ForestMap
## The open ocean: a 2.4 km sea with a flat camp island at the centre, a scatter
## of islands (palms, beaches, a lighthouse), reef shelves ringed with coral,
## kelp forests, sand flats, canyons, shipwrecks, sunken ruins and a whale
## skeleton. The truck arrives as a boat. Terrain is deterministic from the seed
## on every peer; only the host creates sea creatures.
##
## Gameplay water is a flat plane at WATER_LEVEL (swells are visual only, so no
## peer has to agree on a wave clock); `water_depth` / `water_submersion` are all
## that hunters, the boat and the animals ever ask.
const Flora:=preload("res://world/ocean/ocean_flora.gd")
const OCEAN_SEED: int=51727
const WATER_LEVEL: float=0.0
const ISLAND_COUNT: int=17
const CAMP_RADIUS: float=95.0
## Swell constants shared with ocean_water.gdshader: direction, length, amplitude, angular speed.
const SWELLS: Array=[[Vector2(.93,.37),52.0,.30,1.088],[Vector2(.42,.91),27.0,.16,1.51],[Vector2(-.8,.6),13.0,.07,2.17]]
## Minimap compatibility with the swamp's full-map water: no boardwalks here.
const WALKS: Array=[]
const CLIP_CELLS: int=96
const CLIP_LEVELS: int=5
const FLORA_CHUNK: float=64.0

var islands: Array=[]
var landmarks: Array=[]
var floor_material: ShaderMaterial
var clip_rings: Array[MeshInstance3D]=[]
var clip_root: Node3D
var fish_nodes: Array[Node3D]=[]
var flora_counts: Dictionary={}
var reef_spots: Array[Vector3]=[]
var kelp_spot:=Vector3(0,-12,-200)
var wreck_spots: Array[Vector3]=[]
var _island_rng:=RandomNumberGenerator.new()

func _ready() -> void:
    super._ready()
    set_seed(OCEAN_SEED)

## Same layout contract as the other maps: every peer derives the identical sea
## from the one seed the host broadcasts.
func set_seed(value: int) -> void:
    super.set_seed(value)
    noise.frequency=.0042
    noise.fractal_octaves=3
    _make_islands(value)

func _make_islands(value: int) -> void:
    islands.clear()
    _island_rng.seed=value
    islands.append({"c":Vector2.ZERO,"r":CAMP_RADIUS,"peak":1.2,"seed":0.0,"camp":true})
    var tries: int=0
    while islands.size()<ISLAND_COUNT+1 and tries<900:
        tries+=1
        var center:=Vector2(_island_rng.randf_range(-LIMIT+170.0,LIMIT-170.0),_island_rng.randf_range(-LIMIT+170.0,LIMIT-170.0))
        var radius: float=_island_rng.randf_range(34.0,118.0)
        var ok: bool=center.length()>300.0
        for other in islands:
            if center.distance_to(other.c)<radius*2.1+float(other.r)*2.1+60.0: ok=false
        if not ok: continue
        islands.append({"c":center,"r":radius,"peak":_island_rng.randf_range(5.0,20.0)*clampf(radius/80.0,.55,1.3),"seed":_island_rng.randf()*1000.0,"camp":false})

# --- Height field ----------------------------------------------------------------------------

## The open-sea floor before islands: banks, plains, dunes and narrow canyons.
func _seabed(x: float,z: float) -> float:
    var n: float=noise.get_noise_2d(x,z)
    var depth: float=-26.0+n*8.0
    var bank: float=smoothstep(.2,.6,region_noise.get_noise_2d(x,z)*.5+.5)
    depth=lerpf(depth,-8.5+n*2.2,bank*.65)
    var canyon: float=1.0-absf(ridge_noise.get_noise_2d(x+900.0,z-400.0))
    depth-=24.0*smoothstep(.8,.96,canyon)
    depth+=sin(x*.045+n*5.0)*.5+sin(z*.031+x*.012)*.4
    return depth

func _island_height(island: Dictionary,x: float,z: float,base: float) -> float:
    var center: Vector2=island.c
    var dx: float=x-center.x;var dz: float=z-center.y
    var dist: float=sqrt(dx*dx+dz*dz)
    var radius: float=island.r
    if dist>radius*2.2: return -1000.0
    var warp: float=1.0+.26*noise.get_noise_2d(center.x*.3+dx*.012+float(island.seed),center.y*.3+dz*.012)
    var d: float=dist/(radius*warp)
    if d>=2.1: return -1000.0
    if d>1.25: return lerpf(-4.5,base,smoothstep(1.25,2.1,d))
    if island.camp:
        # A flat, low beach island: the truck arrives and the crew steps off here.
        if d<=.5: return 1.2+noise.get_noise_2d(x*.08,z*.08)*.12
        return lerpf(1.2,-4.5,smoothstep(.5,1.25,d))
    var core: float=1.0-smoothstep(0.0,1.25,d)
    var h: float=lerpf(-4.5,float(island.peak),pow(core,.8))
    return h+noise.get_noise_2d(x*.035+float(island.seed),z*.035)*float(island.peak)*.2*core

func height_at(x: float,z: float) -> float:
    var h: float=_seabed(x,z)
    for island in islands:
        var hi: float=_island_height(island,x,z,h)
        if hi>h: h=hi
    # Shoals and reef flats ring the whole map, so the world ends in shallows, not a wall.
    var edge: float=smoothstep(LIMIT-260.0,LIMIT-20.0,maxf(absf(x),absf(z)))
    if edge>0.0:
        var shoal: float=-2.4+noise.get_noise_2d(x*2.0,z*2.0)*3.2+sin(x*.07)*.5
        h=lerpf(h,maxf(h,shoal),edge)
    return h

## 0 on land; how deep the water is over the floor at a point.
func water_level_at(_point: Vector3) -> float: return WATER_LEVEL
func in_lake(_x: float,_z: float) -> bool: return false
func water_depth(point: Vector3) -> float:
    if absf(point.x)>SIZE*.5 or absf(point.z)>SIZE*.5: return 0.0
    return maxf(0.0,WATER_LEVEL-height_at(point.x,point.z))
func water_submersion(point: Vector3) -> float:
    if water_depth(point)<=0.0: return 0.0
    return maxf(0.0,WATER_LEVEL-point.y)
func mud_factor(_point: Vector3) -> float: return 0.0

## Visual swell height at a point and time (mirrors the shader; for effects only).
static func wave_height(point: Vector2,time: float) -> float:
    var total: float=0.0
    for swell in SWELLS:
        var k: float=TAU/float(swell[1])
        total+=sin(point.dot(swell[0].normalized())*k+time*float(swell[3]))*float(swell[2])
    return total

## Places named on the big map.
func map_places() -> Array:
    var places: Array=[["OCEAN_CAMP",Vector3(0,0,10)]]
    for landmark in landmarks: places.append([landmark.key,Vector3(landmark.at.x,0,landmark.at.z)])
    return places

## Spawn points for sea creatures: anywhere with enough water, at the creature's
## preferred depth below the surface; land animals never appear here.
func animal_spawn(entry: AnimalDefinition,point: Vector3) -> Vector3:
    var best:=point
    var wanted: float=maxf(entry.swim_depth,1.5)
    for i in 40:
        var p: Vector3=point+Vector3(sin(i*2.4),0,cos(i*2.4))*i*5.0
        p.x=clampf(p.x,-LIMIT+10.0,LIMIT-10.0);p.z=clampf(p.z,-LIMIT+10.0,LIMIT-10.0)
        var depth: float=water_depth(p)
        if depth<maxf(wanted+2.0,5.0): continue
        best=p;break
    var floor_y: float=height_at(best.x,best.z)
    best.y=clampf(-wanted,floor_y+1.5,-1.0)
    return best

# --- Terrain, water and scatter ------------------------------------------------------------------

func _build_lake() -> void: pass

func _terrain() -> void:
    await super._terrain()
    if cancelled or not is_inside_tree(): return
    var ground: MeshInstance3D=get_child(0)
    floor_material=ShaderMaterial.new();floor_material.shader=load("res://world/ocean/ocean_floor.gdshader")
    floor_material.set_shader_parameter("water_level",WATER_LEVEL)
    ground.material_override=floor_material
    water_material=ShaderMaterial.new();water_material.shader=load("res://world/ocean/ocean_water.gdshader")
    _configure_water_material(1.0)
    _make_clipmap()

## Five square rings of water, each twice as coarse as the one inside it, that
## follow the camera in steps of their own grid size, so the whole sea is one
## displaced surface with fine waves near you and a flat horizon far away.
func _make_clipmap() -> void:
    clip_root=Node3D.new();clip_root.name="Sea";add_child(clip_root)
    var half: int=CLIP_CELLS/2
    var meshes: Array[ArrayMesh]=[]
    for inner in 2:
        var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
        for gz in CLIP_CELLS+1:
            for gx in CLIP_CELLS+1:
                vertices.append(Vector3(gx-half,0,gz-half));normals.append(Vector3.UP)
        var hole: int=half/2-1
        for gz in CLIP_CELLS:
            for gx in CLIP_CELLS:
                if inner==1 and gx>=half-hole and gx<half+hole and gz>=half-hole and gz<half+hole: continue
                var a: int=gz*(CLIP_CELLS+1)+gx
                indices.append_array([a,a+1,a+CLIP_CELLS+1,a+1,a+CLIP_CELLS+2,a+CLIP_CELLS+1])
        var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
        var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        mesh.custom_aabb=AABB(Vector3(-half,-4,-half),Vector3(CLIP_CELLS,8,CLIP_CELLS))
        meshes.append(mesh)
    for level in CLIP_LEVELS:
        var ring:=MeshInstance3D.new();ring.name="Ring"+str(level)
        ring.mesh=meshes[0] if level==0 else meshes[1]
        ring.material_override=water_material
        ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ring.scale=Vector3(2.0*pow(2.0,level),1.0,2.0*pow(2.0,level))
        ring.extra_cull_margin=6.0
        clip_root.add_child(ring);clip_rings.append(ring)

func _follow_camera() -> void:
    var camera:=get_viewport().get_camera_3d() if is_inside_tree() else null
    var center:=Vector3.ZERO
    if camera: center=camera.global_position
    for level in clip_rings.size():
        var cell: float=2.0*pow(2.0,level)
        var snap: float=cell*2.0
        clip_rings[level].position=Vector3(floorf(center.x/snap)*snap,WATER_LEVEL,floorf(center.z/snap)*snap)

func _stream_vegetation(_delta: float) -> void: pass

func _process(delta: float) -> void:
    _follow_camera()
    if floor_material and water_interaction: floor_material.set_shader_parameter("wave_time",water_interaction.elapsed)
    super._process(delta)

## Every island's flora, reefs, kelp forests, wrecks and schools; the base class
## calls this where the forest plants its firs.
func _trees() -> void:
    var rng:=RandomNumberGenerator.new();rng.seed=current_seed
    var variants: Dictionary=_make_variants()
    var groups: Dictionary={}
    flora_counts.clear()
    var span: float=SIZE*.5-30.0
    var steps: int=0
    var kelp_spot_distance: float=INF
    # -- Reef: coral clusters on the shallows, thickest around the islands.
    for attempt in 9000:
        steps+=1
        if steps%260==0:
            build_progress.emit(.62+.1*attempt/9000.0);await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x: float=rng.randf_range(-span,span);var z: float=rng.randf_range(-span,span)
        var h: float=height_at(x,z)
        if h>-1.2 or h<-15.0: continue
        var reef: float=region_noise.get_noise_2d(x*2.6+30.0,z*2.6)*.5+.5
        var near_island: bool=_island_distance(x,z)<2.0
        if reef<(.22 if near_island else .5): continue
        reef_spots.append(Vector3(x,h,z))
        var count: int=rng.randi_range(9,20) if near_island else rng.randi_range(5,11)
        for k in count:
            var px: float=x+rng.randf_range(-9.0,9.0);var pz: float=z+rng.randf_range(-9.0,9.0)
            var ph: float=height_at(px,pz)
            if ph>-.9 or ph<-16.0: continue
            var kind: String=["branching","branching","brain","fan","table","tubes","anemone","fan","branching","brain"][rng.randi()%10]
            if ph<-9.0 and kind=="anemone": kind="tubes"
            var scale_value: float=rng.randf_range(1.0,2.3) if kind in ["branching","table","fan"] else rng.randf_range(.9,1.8)
            _place(groups,variants,kind,Vector3(px,ph-.05,pz),rng,scale_value,rng.randf()*TAU)
    # -- Kelp forests on mid-depth sand, and sea grass meadows in the shallows.
    for attempt in 2600:
        steps+=1
        if steps%260==0:
            build_progress.emit(.72+.07*attempt/2600.0);await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x: float=rng.randf_range(-span,span);var z: float=rng.randf_range(-span,span)
        var h: float=height_at(x,z)
        var forest: float=warp_noise.get_noise_2d(x*1.6,z*1.6)*.5+.5
        if h<-5.0 and h>-26.0 and forest>.52:
            if kelp_spot.y>-5.0 or (Vector2(x,z).length()<kelp_spot_distance and Vector2(x,z).length()>120.0): kelp_spot=Vector3(x,h,z);kelp_spot_distance=Vector2(x,z).length()
            for k in rng.randi_range(5,12):
                var px: float=x+rng.randf_range(-9.0,9.0);var pz: float=z+rng.randf_range(-9.0,9.0)
                var ph: float=height_at(px,pz)
                if ph>-4.0 or ph<-28.0: continue
                _place(groups,variants,"kelp",Vector3(px,ph-.1,pz),rng,rng.randf_range(.8,1.4),rng.randf()*TAU)
        elif h<-1.5 and h>-14.0 and forest<.5:
            for k in rng.randi_range(6,16):
                var px: float=x+rng.randf_range(-6.0,6.0);var pz: float=z+rng.randf_range(-6.0,6.0)
                var ph: float=height_at(px,pz)
                if ph>-1.8 or ph<-15.0: continue
                _place(groups,variants,"seagrass",Vector3(px,ph-.02,pz),rng,rng.randf_range(.8,1.3),rng.randf()*TAU)
    # -- Rocks, urchins, starfish and clams on the floor at every depth.
    for attempt in 3400:
        steps+=1
        if steps%260==0:
            build_progress.emit(.79+.05*attempt/3400.0);await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x: float=rng.randf_range(-span,span);var z: float=rng.randf_range(-span,span)
        var h: float=height_at(x,z)
        if h>-.6: continue
        var roll: float=rng.randf()
        if roll<.5: _place(groups,variants,"rock",Vector3(x,h-.2,z),rng,rng.randf_range(.8,3.4) if h>-26.0 else rng.randf_range(1.6,5.0),rng.randf()*TAU)
        elif h>-14.0 and roll<.7: _place(groups,variants,"urchin",Vector3(x,h,z),rng,rng.randf_range(.8,1.5),rng.randf()*TAU)
        elif h>-12.0 and roll<.85: _place(groups,variants,"starfish",Vector3(x,h+.02,z),rng,rng.randf_range(.8,1.8),rng.randf()*TAU)
        elif h>-14.0: _place(groups,variants,"clam",Vector3(x,h-.05,z),rng,rng.randf_range(.8,1.7),rng.randf()*TAU)
    # -- Islands: palms, ferns and rocks above the waterline.
    for attempt in 4200:
        steps+=1
        if steps%260==0:
            build_progress.emit(.84+.06*attempt/4200.0);await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var island: Dictionary=islands[rng.randi()%islands.size()]
        var angle: float=rng.randf()*TAU;var reach: float=sqrt(rng.randf())*float(island.r)*1.05
        var x: float=float(island.c.x)+cos(angle)*reach;var z: float=float(island.c.y)+sin(angle)*reach
        var h: float=height_at(x,z)
        if h<.9 or h>14.0 or slope_at(x,z)>38.0 or absf(x)>span or absf(z)>span: continue
        if island.camp and (Vector2(x,z).length()<14.0 or (absf(z)<12.0 and x>45.0)): continue
        var roll: float=rng.randf()
        if roll<.58:
            var point:=Vector3(x,h-.15,z)
            _place(groups,variants,"palm",point,rng,rng.randf_range(.85,1.35),rng.randf()*TAU)
            _add_tree(point)
        elif roll<.8: _place_nature(groups,"fern_"+str(0 if rng.randf()<.5 else 3),Vector3(x,h-.02,z),rng,rng.randf_range(1.6,3.2))
        else: _place(groups,variants,"rock",Vector3(x,h-.25,z),rng,rng.randf_range(.8,2.4),rng.randf()*TAU)
    _commit_groups(groups,variants)
    build_progress.emit(.93);await get_tree().process_frame
    if cancelled or not is_inside_tree(): return
    _landmarks(rng,variants)
    await _schools(rng)
    build_progress.emit(.99)

## Smallest island-relative distance (1.0 is the reef edge) at a point.
func _island_distance(x: float,z: float) -> float:
    var best: float=99.0
    for island in islands:
        var center: Vector2=island.c
        best=minf(best,Vector2(x,z).distance_to(center)/float(island.r))
    return best

func _make_variants() -> Dictionary:
    var coral: ShaderMaterial=Flora.shader_material(.38,1.25)
    var stone: ShaderMaterial=Flora.shader_material(.0,.9)
    var palm_material: ShaderMaterial=Flora.shader_material(.04,1.1)
    var kelp_material:=ShaderMaterial.new();kelp_material.shader=load("res://world/ocean/kelp.gdshader")
    var grass_material:=ShaderMaterial.new();grass_material.shader=load("res://world/ocean/kelp.gdshader")
    grass_material.set_shader_parameter("sway_amount",.35);grass_material.set_shader_parameter("sway_speed",1.6)
    var out: Dictionary={}
    var plan: Dictionary={
        "branching":[4,coral,125.0],"brain":[3,coral,115.0],"fan":[3,coral,125.0],"table":[3,coral,130.0],"tubes":[3,coral,115.0],
        "anemone":[3,coral,80.0],"urchin":[2,stone,60.0],"starfish":[2,coral,60.0],"clam":[2,coral,85.0],"rock":[4,stone,260.0],
        "kelp":[3,kelp_material,150.0],"seagrass":[3,grass_material,80.0],"palm":[4,palm_material,320.0],
    }
    for kind in plan:
        var entry: Array=plan[kind]
        var list: Array=[]
        for v in int(entry[0]):
            var mesh: ArrayMesh=Flora.make(kind,current_seed+v*131+kind.hash()%977)
            mesh.surface_set_material(0,entry[1])
            list.append(mesh)
        out[kind]={"meshes":list,"range":float(entry[2])}
    return out

func _place(groups: Dictionary,variants: Dictionary,kind: String,point: Vector3,rng: RandomNumberGenerator,scale_value: float,yaw: float) -> void:
    var list: Array=variants[kind].meshes
    var variant: int=rng.randi()%list.size()
    var basis:=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value)
    if kind in ["rock","brain","table","clam"]: basis=Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(scale_value,scale_value*rng.randf_range(.7,1.2),scale_value))
    var key:=Vector4i(floori(point.x/FLORA_CHUNK),floori(point.z/FLORA_CHUNK),kind.hash()%100000,variant)
    if not groups.has(key): groups[key]={"kind":kind,"variant":variant,"transforms":[]}
    groups[key].transforms.append(Transform3D(basis,point))
    flora_counts[kind]=int(flora_counts.get(kind,0))+1

func _place_nature(groups: Dictionary,id: String,point: Vector3,rng: RandomNumberGenerator,scale_value: float) -> void:
    var key:=Vector4i(floori(point.x/FLORA_CHUNK),floori(point.z/FLORA_CHUNK),id.hash()%100000,-1)
    if not groups.has(key): groups[key]={"kind":id,"variant":-1,"transforms":[]}
    groups[key].transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),point))
    flora_counts["fern"]=int(flora_counts.get("fern",0))+1

func _commit_groups(groups: Dictionary,variants: Dictionary) -> void:
    for key in groups:
        var group: Dictionary=groups[key]
        var mesh: Mesh
        var reach: float=130.0
        if group.variant<0:
            mesh=GameArt.nature_mesh(group.kind);reach=170.0
        else:
            mesh=variants[group.kind].meshes[group.variant];reach=variants[group.kind].range
        var node:=_multimesh(mesh,group.transforms,reach,0,group.kind in ["rock","palm"])
        node.name=str(group.kind).capitalize()+str(key.x)+"_"+str(key.y)

# --- Landmarks ---------------------------------------------------------------------------------------

func _spot(node: Node3D,mesh: Mesh,point: Vector3,yaw: float,reach: float,scale_value: float=1.0) -> MeshInstance3D:
    var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.position=point;instance.rotation.y=yaw;instance.scale=Vector3.ONE*scale_value
    instance.visibility_range_end=reach;node.add_child(instance)
    return instance

func _tag(key: String,point: Vector3,reach: float=140.0) -> Label3D:
    var label:=Label3D.new();label.position=point;label.font_size=34;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    label.visibility_range_end=reach;label.modulate=Color("efe6c4");label.outline_size=10;label.set_meta("key",key);label.text=tr(key)
    add_child(label)
    LocaleSettings.changed.connect(func() -> void: label.text=tr(key))
    return label

func _landmarks(rng: RandomNumberGenerator,variants: Dictionary) -> void:
    landmarks.clear()
    var solid: StandardMaterial3D=Flora.solid_material()
    var leaf: StandardMaterial3D=Flora.leaf_material()
    var props:=Node3D.new();props.name="Landmarks";add_child(props)
    # The camp island's pier, a short walk from where the truck parks.
    var pier: ArrayMesh=Flora.pier(46.0);pier.surface_set_material(0,solid)
    var pier_node:=_spot(props,pier,Vector3(52.0,1.45,14.0),-PI*.5,260.0)
    pier_node.scale=Vector3(1.5,1.0,1.0)
    var deck:=StaticBody3D.new();deck.position=Vector3(75.0,1.4,14.0);props.add_child(deck)
    var deck_shape:=CollisionShape3D.new();var deck_box:=BoxShape3D.new();deck_box.size=Vector3(46.0,.3,5.0);deck_shape.shape=deck_box;deck.add_child(deck_shape)
    for k in 4:
        var lamp:=OmniLight3D.new();lamp.position=Vector3(58.0+k*12.0,3.1,12.0);lamp.light_color=Color("ffcf8a");lamp.light_energy=1.2;lamp.omni_range=11
        lamp.distance_fade_enabled=true;lamp.distance_fade_begin=40;props.add_child(lamp)
    _tag("OCEAN_CAMP",Vector3(0,5.5,8.0),90.0)
    # The lighthouse on the largest island.
    var tallest: Dictionary={}
    for island in islands:
        if island.camp: continue
        if tallest.is_empty() or float(island.r)>float(tallest.r): tallest=island
    if not tallest.is_empty():
        var base: Vector3=Vector3(tallest.c.x,height_at(tallest.c.x,tallest.c.y)-.5,tallest.c.y)
        var tower: ArrayMesh=Flora.lighthouse();tower.surface_set_material(0,solid)
        _spot(props,tower,base,0.0,900.0)
        var beam:=SpotLight3D.new();beam.name="LighthouseBeam";beam.position=base+Vector3(0,29.0,0);beam.light_color=Color("fff0c0");beam.light_energy=6.0
        beam.spot_range=380;beam.spot_angle=9;beam.rotation_degrees=Vector3(-3,0,0);props.add_child(beam)
        var lamp_mesh:=MeshInstance3D.new();var lens:=SphereMesh.new();lens.radius=1.2;lens.height=2.4
        var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ffe9a0");glow.emission_enabled=true;glow.emission=Color("ffd870");glow.emission_energy_multiplier=3.0
        lens.material=glow;lamp_mesh.mesh=lens;lamp_mesh.position=base+Vector3(0,28.7,0);props.add_child(lamp_mesh)
        set_meta("lighthouse_beam",beam)
        landmarks.append({"key":"OCEAN_LIGHTHOUSE","at":base})
        _tag("OCEAN_LIGHTHOUSE",base+Vector3(0,40.0,0),600.0)
    # Shipwrecks, sunken ruins and a whale skeleton on sand flats.
    var wanted: Array=[["wreck",3,"OCEAN_WRECK"],["ruins",1,"OCEAN_RUINS"],["whale",1,"OCEAN_WHALE"]]
    for entry in wanted:
        var found: int=0
        for attempt in 400:
            if found>=int(entry[1]): break
            var x: float=rng.randf_range(-SIZE*.5+260.0,SIZE*.5-260.0);var z: float=rng.randf_range(-SIZE*.5+260.0,SIZE*.5-260.0)
            var h: float=height_at(x,z)
            if h>-12.0 or h<-26.0 or slope_at(x,z)>9.0 or Vector2(x,z).length()<200.0: continue
            var clear: bool=true
            for other in landmarks:
                if Vector2(x,z).distance_to(Vector2(other.at.x,other.at.z))<160.0: clear=false
            if not clear: continue
            var at:=Vector3(x,h-.4,z)
            var yaw: float=rng.randf()*TAU
            match entry[0]:
                "wreck":
                    var mesh: ArrayMesh=Flora.shipwreck(current_seed+found);mesh.surface_set_material(0,solid)
                    var node:=_spot(props,mesh,at+Vector3(0,.6,0),yaw,260.0)
                    node.rotation.z=rng.randf_range(-.28,.28);node.rotation.x=rng.randf_range(-.1,.1)
                    var chest_mesh: ArrayMesh=Flora.chest();chest_mesh.surface_set_material(0,solid)
                    var chest_at: Vector3=at+Vector3(cos(yaw)*5.0,.2,-sin(yaw)*5.0)
                    _spot(props,chest_mesh,chest_at,yaw,120.0,1.4)
                    var gleam:=OmniLight3D.new();gleam.position=chest_at+Vector3(0,1.4,0);gleam.light_color=Color("ffd870");gleam.light_energy=1.6;gleam.omni_range=9;gleam.distance_fade_enabled=true;gleam.distance_fade_begin=50;props.add_child(gleam)
                "ruins":
                    var mesh: ArrayMesh=Flora.ruins(current_seed);mesh.surface_set_material(0,solid)
                    _spot(props,mesh,at,yaw,300.0,1.4)
                "whale":
                    var mesh: ArrayMesh=Flora.whale_bones();mesh.surface_set_material(0,solid)
                    _spot(props,mesh,at,yaw,260.0,1.2)
            if entry[0]=="wreck": wreck_spots.append(at)
            landmarks.append({"key":entry[2],"at":at})
            _tag(entry[2],at+Vector3(0,9.0,0),170.0)
            found+=1

# --- Schools of fish and drifting rays (cosmetic, local) --------------------------------------------------

func _schools(rng: RandomNumberGenerator) -> void:
    var fish_meshes: Array[ArrayMesh]=[Flora.reef_fish(0),Flora.reef_fish(1),Flora.reef_fish(2),Flora.reef_fish(3),Flora.reef_fish(4),Flora.fish_body()]
    var manta: ArrayMesh=Flora.manta()
    var span: float=SIZE*.5-60.0
    var made: int=0
    for attempt in 600:
        if made>=110: break
        if attempt%60==0:
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x: float=rng.randf_range(-span,span);var z: float=rng.randf_range(-span,span)
        var h: float=height_at(x,z)
        if h>-4.0: continue
        var top: float=maxf(h+3.0,-26.0)
        var y: float=rng.randf_range(top,-2.5) if top<-2.5 else -3.0
        var count: int=rng.randi_range(24,48)
        var material:=ShaderMaterial.new();material.shader=load("res://world/ocean/fish_school.gdshader")
        material.set_shader_parameter("school_scale",rng.randf_range(.9,1.8))
        var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.use_custom_data=true
        var variant: int=rng.randi()%fish_meshes.size()
        multimesh.mesh=fish_meshes[variant];multimesh.instance_count=count
        var hue: float=rng.randf()
        var radius: float=rng.randf_range(2.5,6.0)
        for i in count:
            multimesh.set_instance_transform(i,Transform3D.IDENTITY)
            # Reef fish keep their own colours (a faint tint); the plain fish take a school colour.
            multimesh.set_instance_color(i,Color.from_hsv(fposmod(hue+rng.randf_range(-.04,.04),1.0),rng.randf_range(.0,.18) if variant<5 else rng.randf_range(.25,.7),rng.randf_range(.88,1.0)))
            multimesh.set_instance_custom_data(i,Color(rng.randf()*TAU,radius*rng.randf_range(.7,1.3),rng.randf_range(.45,.75),rng.randf_range(.3,1.1)))
        var node:=MultiMeshInstance3D.new();node.multimesh=multimesh;node.material_override=material
        node.position=Vector3(x,y,z);node.visibility_range_end=130.0;node.set_meta("draw_end",130.0);node.set_meta("draw_begin",0.0)
        node.custom_aabb=AABB(Vector3(-12,-6,-12),Vector3(24,12,24))
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node);fish_nodes.append(node);made+=1
    for k in 6:
        var x: float=rng.randf_range(-span,span);var z: float=rng.randf_range(-span,span)
        var material:=ShaderMaterial.new();material.shader=load("res://world/ocean/fish_school.gdshader")
        material.set_shader_parameter("school_scale",rng.randf_range(1.6,2.4))
        var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.use_custom_data=true
        multimesh.mesh=manta;multimesh.instance_count=2
        for i in 2:
            multimesh.set_instance_transform(i,Transform3D.IDENTITY)
            multimesh.set_instance_color(i,Color(1,1,1))
            multimesh.set_instance_custom_data(i,Color(rng.randf()*TAU,rng.randf_range(40.0,90.0),rng.randf_range(.07,.12),rng.randf_range(1.0,3.0)))
        var node:=MultiMeshInstance3D.new();node.multimesh=multimesh;node.material_override=material
        node.position=Vector3(x,rng.randf_range(-12.0,-5.0),z);node.visibility_range_end=260.0;node.set_meta("draw_end",260.0);node.set_meta("draw_begin",0.0)
        node.custom_aabb=AABB(Vector3(-130,-8,-130),Vector3(260,16,260))
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node);fish_nodes.append(node)
