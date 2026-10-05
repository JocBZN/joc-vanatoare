class_name ForestMap
extends Node3D
## Deterministic terrain on every peer. Only the host creates wildlife.
const SIZE: float = 1200.0
const STEP: float = 6.0
const SEED: int = 10337
const LAKE_CENTER := Vector2(190.0, 160.0)
const LAKE_RADIUS: float = 72.0
const LAKE_SHORE: float = 26.0
const LAKE_LEVEL: float = -3.0
signal build_progress(value: float)
var built: bool=false
var cancelled: bool=false
var noise := FastNoiseLite.new()
var region_noise := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()
var trees: Array[Vector3] = []
var colliders: Dictionary = {}
var collider_clock: float = 0.0
var water_material: ShaderMaterial
var current_seed: int = SEED

## Re-seeds every noise layer from a single value; called by WorldRouter before build() with a
## fresh random seed chosen by the host and broadcast to every peer, so each expedition gets a
## different mountain/tree layout that still matches on every machine. _ready() calls this with
## the fixed default so anything that instantiates a map directly (tests, previews) still behaves
## exactly as before unless a session explicitly overrides it.
func set_seed(value: int) -> void:
    current_seed = value
    noise.seed = value
    region_noise.seed = value + 1
    warp_noise.seed = value + 2
    ridge_noise.seed = value + 3

## Ridged, domain-warped noise masked to patches far from camp: real climbable peaks out in
## the wilds, while the terrain near the fire and the first hunt corridor stays exactly as before.
func mountains_at(x: float, z: float, dist: float) -> float:
    var region: float = clampf(region_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
    region = smoothstep(0.4, 0.78, region)
    var warp_x: float = x + warp_noise.get_noise_2d(x * 0.6, z * 0.6) * 70.0
    var warp_z: float = z + warp_noise.get_noise_2d(x * 0.6 + 500.0, z * 0.6 + 500.0) * 70.0
    var ridge: float = 1.0 - absf(ridge_noise.get_noise_2d(warp_x, warp_z))
    ridge = pow(clampf(ridge, 0.0, 1.0), 2.4)
    var mountain_fade: float = smoothstep(110.0, 260.0, dist)
    # The jeep route runs the full length of the map, not just near camp; keep it passable
    # wherever it winds through the new mountain belt instead of climbing straight up a peak.
    var road_x: float = sin(z * 0.012) * 28.0
    var road_clear: float = smoothstep(16.0, 55.0, absf(x - road_x))
    return ridge * region * mountain_fade * road_clear * 46.0

func lake_basin(height: float, x: float, z: float) -> float:
    var dist: float = Vector2(x, z).distance_to(LAKE_CENTER)
    var basin: float = 1.0 - smoothstep(LAKE_RADIUS, LAKE_RADIUS + LAKE_SHORE, dist)
    return lerpf(height, LAKE_LEVEL, basin)

func height_at(x: float, z: float) -> float:
    var dist: float = Vector2(x, z).length()
    var fade := smoothstep(35.0, 80.0, dist)
    var height: float = noise.get_noise_2d(x, z) * 12.0 * fade + mountains_at(x, z, dist)
    return lake_basin(height, x, z)

## Local slope in degrees, estimated from the height field itself (central differences);
## used to keep animals off cliff faces and trees from rooting on them.
func slope_at(x: float, z: float) -> float:
    var eps: float = 2.0
    var dx: float = height_at(x + eps, z) - height_at(x - eps, z)
    var dz: float = height_at(x, z + eps) - height_at(x, z - eps)
    return rad_to_deg(atan(Vector2(dx, dz).length() / (2.0 * eps)))

func in_lake(x: float, z: float) -> bool:
    return Vector2(x, z).distance_to(LAKE_CENTER) < LAKE_RADIUS + LAKE_SHORE * .7

func animal_spawn(entry: AnimalDefinition, point: Vector3) -> Vector3:
    var best := point
    for i in 20:
        var p: Vector3 = point + Vector3(sin(i * 2.4), 0, cos(i * 2.4)) * i * 4.0
        p.x = clampf(p.x, -580, 580); p.z = clampf(p.z, -580, 580)
        if not in_lake(p.x, p.z) and slope_at(p.x, p.z) <= entry.max_slope:
            best = p; break
    best.y = height_at(best.x, best.z) + .12
    return best

func _ready() -> void:
    LocaleSettings.changed.connect(_quality)
    noise.frequency = 0.006
    noise.fractal_octaves = 3
    region_noise.frequency = 0.0014
    region_noise.fractal_octaves = 2
    warp_noise.frequency = 0.003
    ridge_noise.frequency = 0.0032
    ridge_noise.fractal_octaves = 4
    set_seed(SEED)

func build() -> void:
    await _terrain()
    if cancelled or not is_inside_tree(): return
    await _trees()
    if cancelled or not is_inside_tree(): return
    _quality()
    built=true
    build_progress.emit(1.0)

func _terrain() -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for iz in 200:
        if iz%16==0:
            build_progress.emit(.05+.55*iz/200.0)
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        for ix in 200:
            var x := ix * STEP - SIZE * 0.5
            var z := iz * STEP - SIZE * 0.5
            for offset in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(1,1), Vector2(0,1)]:
                var px: float = x + offset.x * STEP
                var pz: float = z + offset.y * STEP
                surface.set_uv(Vector2(px, pz) / 20.0)
                surface.add_vertex(Vector3(px, height_at(px,pz) - 0.015, pz))
    surface.generate_normals()
    surface.generate_tangents()
    surface.index()
    var mesh := surface.commit()
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    var material := GameArt.ground_material()
    visual.material_override = material
    add_child(visual)
    var ground := StaticBody3D.new()
    add_child(ground)
    var collision := CollisionShape3D.new()
    collision.shape = mesh.create_trimesh_shape()
    ground.add_child(collision)
    _build_lake()

## Overridden to a no-op by SwampMap, which already owns a full-map water system.
func _build_lake() -> void:
    water_material = ShaderMaterial.new(); water_material.shader = load("res://world/forest/forest_lake.gdshader")
    water_material.set_shader_parameter("normal_map", GameArt.texture("forest_ground_04", "nor_gl"))
    water_material.set_shader_parameter("lake_center", LAKE_CENTER)
    water_material.set_shader_parameter("lake_radius", LAKE_RADIUS)
    water_material.set_shader_parameter("lake_shore", LAKE_SHORE)
    var water := MeshInstance3D.new(); water.name = "Lake"
    var lake_span: float = (LAKE_RADIUS + LAKE_SHORE) * 2.0
    var plane := PlaneMesh.new(); plane.size = Vector2(lake_span, lake_span); plane.subdivide_width = 24; plane.subdivide_depth = 24
    water.mesh = plane; water.material_override = water_material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    water.position = Vector3(LAKE_CENTER.x, LAKE_LEVEL, LAKE_CENTER.y)
    add_child(water)

func _trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = SEED
    var chunks: Dictionary = {}
    for index in 6500:
        if index%650==0:
            build_progress.emit(.62+.06*index/6500.0)
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x := rng.randf_range(-588,588)
        var z := rng.randf_range(-588,588)
        if Vector2(x,z).length() < 42 or absf(x - sin(z * 0.012) * 28.0 * smoothstep(35,80,absf(z))) < 5.5:
            continue
        if in_lake(x,z) or slope_at(x,z) > 48.0:
            continue
        var point := Vector3(x,height_at(x,z),z)
        trees.append(point)
        var key := Vector3i(floori(x/64),floori(z/64),1 if rng.randf()<.35 else 0)
        if not chunks.has(key): chunks[key] = []
        chunks[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.8,1.6)),point))
    var chunk_index:=0
    for key in chunks:
        chunk_index+=1
        if chunk_index%24==0:
            build_progress.emit(.68+.17*chunk_index/float(chunks.size()))
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var id: String="fir_"+"abc"[posmod(key.x+key.y+key.z,3)]
        _multimesh(GameArt.nature_mesh(id),chunks[key],130,0,true)
        _multimesh(GameArt.impostor(id),chunks[key],430,125,false)
    await _undergrowth(rng)

func _multimesh(mesh: Mesh,transforms: Array,end: float,begin: float=0,shadows: bool=false) -> MultiMeshInstance3D:
    var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh
    mm.instance_count=transforms.size()
    var anchor: Vector3=transforms[0].origin
    for index in transforms.size():
        var transform: Transform3D=transforms[index];transform.origin-=anchor
        mm.set_instance_transform(index,transform)
    var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.position=anchor
    node.set_meta("draw_end",end);node.set_meta("draw_begin",begin)
    node.visibility_range_end=end;node.visibility_range_begin=begin
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node);return node

func _undergrowth(_rng: RandomNumberGenerator) -> void:
    for id in ["grass_patch_small_a","grass_patch_small_b","grass_patch_mid_a","grass_0","grass_3","grass_4","grass_5","grass_6","fern_0","fern_3","rock_0","rock_1","rock_2"]:
        GameArt.nature_mesh(id)
        await get_tree().process_frame
        if cancelled or not is_inside_tree(): return
    build_progress.emit(.99)

var vegetation: Dictionary={}
var vegetation_queue: Array[Vector2i]=[]
var vegetation_clock: float=0
const PLANT_SECTOR: float=32

func _stream_vegetation(delta: float) -> void:
    if DisplayServer.get_name()=="headless": return
    vegetation_clock-=delta
    var camera:=get_viewport().get_camera_3d()
    if not camera: return
    if vegetation_clock<=0:
        vegetation_clock=.3
        var radius: int=2 if LocaleSettings.graphics=="low" else 4 if LocaleSettings.graphics=="high" else 3
        var origin:=Vector2i(floori(camera.global_position.x/PLANT_SECTOR),floori(camera.global_position.z/PLANT_SECTOR))
        var wanted: Dictionary={}
        for x in range(origin.x-radius,origin.x+radius+1):
            for z in range(origin.y-radius,origin.y+radius+1):
                var key:=Vector2i(x,z)
                if absf(x*PLANT_SECTOR)>SIZE*.5 or absf(z*PLANT_SECTOR)>SIZE*.5: continue
                wanted[key]=true
                if not vegetation.has(key) and not vegetation_queue.has(key): vegetation_queue.append(key)
        vegetation_queue=vegetation_queue.filter(func(key: Vector2i) -> bool: return wanted.has(key))
        vegetation_queue.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.distance_squared_to(origin)<b.distance_squared_to(origin))
        for key in vegetation.keys():
            if not wanted.has(key):
                for node in vegetation[key]: node.queue_free()
                vegetation.erase(key)
    # Bound generation to one sector per frame; distant sectors arrive gradually.
    if not vegetation_queue.is_empty(): _plant_sector(vegetation_queue.pop_front())

func _plant_sector(key: Vector2i) -> void:
    var rng:=RandomNumberGenerator.new();rng.seed=SEED+key.x*73856093+key.y*19349663
    var groups: Dictionary={}
    for attempt in 2100:
        var x: float=(key.x+rng.randf())*PLANT_SECTOR
        var z: float=(key.y+rng.randf())*PLANT_SECTOR
        if Vector2(x,z).length()<17 or absf(x-sin(z*.012)*28*smoothstep(35,80,absf(z)))<4.7: continue
        if noise.get_noise_2d(x*4,z*4)<-.28: continue
        if in_lake(x,z): continue
        var kind: String="grass_"+str(rng.randi_range(3,6))
        var scale_factor: float=rng.randf_range(2.6,4.6)
        if attempt%60==0: kind="fern_"+str(0 if rng.randf()<.5 else 3);scale_factor=rng.randf_range(1.2,2.4)
        elif attempt%280==0: kind="rock_"+str(rng.randi_range(0,2));scale_factor=rng.randf_range(.35,.9)
        elif attempt%3==0: kind="grass_patch_small_"+("a" if rng.randf()<.5 else "b");scale_factor=rng.randf_range(3.3,4.6)
        elif attempt%17==0: kind="grass_patch_mid_a";scale_factor=rng.randf_range(2.6,3.5)
        if not groups.has(kind): groups[kind]=[]
        var point:=Vector3(x,height_at(x,z)-.005,z)
        groups[kind].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_factor),point))
    vegetation[key]=[]
    for kind in groups:
        var node:=_multimesh(GameArt.nature_mesh(kind),groups[kind],170 if kind.begins_with("rock") else 120,0,kind.begins_with("rock"))
        vegetation[key].append(node)

func _process(delta: float) -> void:
    if not built: return
    _stream_vegetation(delta)
    if water_material:
        var hunter=NetworkSession.local_hunter()
        if is_instance_valid(hunter): water_material.set_shader_parameter("observer",hunter.global_position)
    collider_clock -= delta
    if collider_clock > 0: return
    collider_clock = 1.0
    var observers: Array[Vector3] = []
    for p in NetworkSession.players.values():
        if NetworkSession.is_host() or p.local_player: observers.append(p.global_position)
    if is_instance_valid(NetworkSession.jeep): observers.append(NetworkSession.jeep.global_position)
    var wanted: Dictionary = {}
    for i in trees.size():
        for observer in observers:
            if trees[i].distance_squared_to(observer) < 75*75:
                wanted[i] = true
                break
    for i in colliders.keys():
        if not wanted.has(i):
            colliders[i].queue_free()
            colliders.erase(i)
    for i in wanted:
        if colliders.has(i): continue
        var body := StaticBody3D.new()
        add_child(body)
        body.position = trees[i]+Vector3(0,3,0)
        var c := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius=.36
        shape.height=6
        c.shape=shape
        body.add_child(c)
        colliders[i]=body

func _quality() -> void:
    var factor: float=.7 if LocaleSettings.graphics=="low" else 1.3 if LocaleSettings.graphics=="high" else 1
    for node in get_children():
        if node is MultiMeshInstance3D:
            node.visibility_range_end=float(node.get_meta("draw_end"))*factor
            node.visibility_range_begin=float(node.get_meta("draw_begin"))*factor
