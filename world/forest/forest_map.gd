class_name ForestMap
extends Node3D
## Deterministic terrain on every peer. Only the host creates wildlife.
## 2.4 km across, so the truck is the way to get around.
const SIZE: float = 2400.0
const STEP: float = 8.0
const CELLS: int = 300
## Hunters, wildlife and the truck stay this far inside the edge.
const LIMIT: float = SIZE * 0.5 - 10.0
## Tree collider buckets, so only trees near a hunter or the truck are scanned.
const TREE_CELL: float = 32.0
const SEED: int = 10337
const LAKE_CENTER := Vector2(190.0, 160.0)
const LAKE_RADIUS: float = 72.0
const LAKE_SHORE: float = 26.0
const LAKE_LEVEL: float = -3.0
const LAKE_DEPTH: float = 1.15
signal build_progress(value: float)
var built: bool=false
var cancelled: bool=false
var noise := FastNoiseLite.new()
var region_noise := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()
var trees: Array[Vector3] = []
var tree_cells: Dictionary = {}
## Height samples of the built terrain, (CELLS+1) x (CELLS+1), row by row from
## the north-west corner. The minimap paints its relief from them.
var heights: PackedFloat32Array
var colliders: Dictionary = {}
var collider_clock: float = 0.0
var water_material: ShaderMaterial
var water_interaction: WaterInteraction
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
    var depth: float = LAKE_DEPTH * (1.0 - smoothstep(LAKE_RADIUS * .45, LAKE_RADIUS + LAKE_SHORE * .7, dist))
    # Random lowlands must not open a deep trough in the walkable lake's rim.
    # A low earthen bank fades gently back into the unchanged terrain beyond it.
    var bank_weight: float = 1.0 - smoothstep(LAKE_RADIUS + LAKE_SHORE, LAKE_RADIUS + LAKE_SHORE + 14.0, dist)
    var bank_height: float = lerpf(height, maxf(height, LAKE_LEVEL + .2), bank_weight)
    return lerpf(bank_height, LAKE_LEVEL - depth, basin)

func height_at(x: float, z: float) -> float:
    var dist: float = Vector2(x, z).length()
    var fade := smoothstep(35.0, 80.0, dist)
    var height: float = noise.get_noise_2d(x, z) * 12.0 * fade + mountains_at(x, z, dist) + rim_at(x, z)
    return lake_basin(height, x, z)

## Wooded hills rise along the edge, so the world ends in a ridge, not a cliff.
func rim_at(x: float, z: float) -> float:
    var rise: float = smoothstep(SIZE * 0.5 - 190.0, SIZE * 0.5 - 25.0, maxf(absf(x), absf(z)))
    if rise <= 0.0: return 0.0
    return rise * (26.0 + region_noise.get_noise_2d(x * 2.0, z * 2.0) * 12.0)

## Local slope in degrees, estimated from the height field itself (central differences);
## used to keep animals off cliff faces and trees from rooting on them.
func slope_at(x: float, z: float) -> float:
    var eps: float = 2.0
    var dx: float = height_at(x + eps, z) - height_at(x - eps, z)
    var dz: float = height_at(x, z + eps) - height_at(x, z - eps)
    return rad_to_deg(atan(Vector2(dx, dz).length() / (2.0 * eps)))

func in_lake(x: float, z: float) -> bool:
    return Vector2(x, z).distance_to(LAKE_CENTER) < LAKE_RADIUS + LAKE_SHORE and height_at(x, z) < LAKE_LEVEL

## Gameplay uses the nominal plane on every peer; small visual waves have no effect
## on prediction, and being above water on a bridge never applies water drag.
func water_level_at(_point: Vector3) -> float: return LAKE_LEVEL

func water_depth(point: Vector3) -> float:
    if not in_lake(point.x, point.z): return 0.0
    return maxf(0.0, water_level_at(point) - height_at(point.x, point.z))

func water_submersion(point: Vector3) -> float:
    if water_depth(point) <= 0.0: return 0.0
    return maxf(0.0, water_level_at(point) - point.y)

func animal_spawn(entry: AnimalDefinition, point: Vector3) -> Vector3:
    var best := point
    for i in 20:
        var p: Vector3 = point + Vector3(sin(i * 2.4), 0, cos(i * 2.4)) * i * 4.0
        p.x = clampf(p.x, -LIMIT + 10.0, LIMIT - 10.0); p.z = clampf(p.z, -LIMIT + 10.0, LIMIT - 10.0)
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

## One indexed grid: every height is sampled once and shared by the six
## triangles around it, with normals taken from the neighbouring samples.
func _terrain() -> void:
    var count: int = CELLS + 1
    var half: float = SIZE * 0.5
    heights.resize(count * count)
    var vertices := PackedVector3Array(); vertices.resize(count * count)
    var uvs := PackedVector2Array(); uvs.resize(count * count)
    for iz in count:
        if iz % 30 == 0:
            build_progress.emit(.05 + .35 * iz / float(count))
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var z: float = iz * STEP - half
        for ix in count:
            var x: float = ix * STEP - half
            var h: float = height_at(x, z)
            var index: int = iz * count + ix
            heights[index] = h
            vertices[index] = Vector3(x, h - 0.015, z)
            uvs[index] = Vector2(x, z) / 20.0
    var normals := PackedVector3Array(); normals.resize(count * count)
    for iz in count:
        if iz % 60 == 0:
            build_progress.emit(.4 + .12 * iz / float(count))
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var up: int = maxi(iz - 1, 0); var down: int = mini(iz + 1, CELLS)
        for ix in count:
            var left: int = maxi(ix - 1, 0); var right: int = mini(ix + 1, CELLS)
            var dx: float = (heights[iz * count + right] - heights[iz * count + left]) / (STEP * (right - left))
            var dz: float = (heights[down * count + ix] - heights[up * count + ix]) / (STEP * (down - up))
            normals[iz * count + ix] = Vector3(-dx, 1.0, -dz).normalized()
    var indices := PackedInt32Array(); indices.resize(CELLS * CELLS * 6)
    var cursor: int = 0
    for iz in CELLS:
        for ix in CELLS:
            var a: int = iz * count + ix
            indices[cursor] = a; indices[cursor + 1] = a + 1; indices[cursor + 2] = a + count
            indices[cursor + 3] = a + 1; indices[cursor + 4] = a + count + 1; indices[cursor + 5] = a + count
            cursor += 6
    var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    build_progress.emit(.56)
    await get_tree().process_frame
    if cancelled or not is_inside_tree(): return
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    var material := GameArt.ground_material()
    material.set_shader_parameter("lake_center", LAKE_CENTER)
    material.set_shader_parameter("lake_radius", LAKE_RADIUS)
    material.set_shader_parameter("lake_shore", LAKE_SHORE)
    material.set_shader_parameter("lake_level", LAKE_LEVEL)
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
    _configure_water_material(1.0)
    water_material.set_shader_parameter("lake_center", LAKE_CENTER)
    water_material.set_shader_parameter("lake_radius", LAKE_RADIUS)
    water_material.set_shader_parameter("lake_shore", LAKE_SHORE)
    var water := MeshInstance3D.new(); water.name = "Lake"
    var lake_span: float = (LAKE_RADIUS + LAKE_SHORE) * 2.0
    var plane := PlaneMesh.new(); plane.size = Vector2(lake_span, lake_span); plane.subdivide_width = 128; plane.subdivide_depth = 128
    water.mesh = plane; water.material_override = water_material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    water.position = Vector3(LAKE_CENTER.x, LAKE_LEVEL, LAKE_CENTER.y)
    add_child(water)

func _configure_water_material(wave_strength: float, wave_spatial_scale: float = 1.0) -> void:
    water_material.set_shader_parameter("normal_map", load("res://assets/art/water/water_normal.png"))
    water_material.set_shader_parameter("detail_normal", load("res://assets/art/water/water_detail_normal.png"))
    water_material.set_shader_parameter("foam_texture", load("res://assets/art/water/water_foam.png"))
    water_material.set_shader_parameter("wave_strength", wave_strength)
    water_material.set_shader_parameter("wave_spatial_scale", wave_spatial_scale)
    water_interaction = WaterInteraction.new()
    water_interaction.configure(self, water_material)

func _trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = SEED
    var chunks: Dictionary = {}
    var span: float = SIZE * 0.5 - 12.0
    for index in 24000:
        if index%2000==0:
            build_progress.emit(.62+.06*index/24000.0)
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x := rng.randf_range(-span,span)
        var z := rng.randf_range(-span,span)
        if Vector2(x,z).length() < 42 or absf(x - sin(z * 0.012) * 28.0 * smoothstep(35,80,absf(z))) < 5.5:
            continue
        if in_lake(x,z) or slope_at(x,z) > 48.0:
            continue
        var point := Vector3(x,height_at(x,z),z)
        _add_tree(point)
        var key := Vector3i(floori(x/64),floori(z/64),1 if rng.randf()<.35 else 0)
        if not chunks.has(key): chunks[key] = []
        chunks[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.8,1.6)),point))
    var chunk_index:=0
    for key in chunks:
        chunk_index+=1
        # A frame per batch keeps the loading bar moving without spending a
        # rendered frame on every few dozen of the ~2 800 chunks.
        if chunk_index%96==0:
            build_progress.emit(.68+.17*chunk_index/float(chunks.size()))
            await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var id: String="fir_"+"abc"[posmod(key.x+key.y+key.z,3)]
        _multimesh(GameArt.nature_mesh(id),chunks[key],130,0,true)
        _multimesh(GameArt.impostor(id),chunks[key],430,125,false)
    await _undergrowth(rng)

func _add_tree(point: Vector3) -> void:
    var cell := Vector2i(floori(point.x / TREE_CELL), floori(point.z / TREE_CELL))
    if not tree_cells.has(cell): tree_cells[cell] = PackedInt32Array()
    tree_cells[cell].append(trees.size())
    trees.append(point)

## Indices of the trees within `radius` of `point` (bucketed, never a full scan).
func trees_near(point: Vector3, radius: float) -> PackedInt32Array:
    var found := PackedInt32Array()
    var reach: int = ceili(radius / TREE_CELL)
    var origin := Vector2i(floori(point.x / TREE_CELL), floori(point.z / TREE_CELL))
    for cx in range(origin.x - reach, origin.x + reach + 1):
        for cz in range(origin.y - reach, origin.y + reach + 1):
            var cell := Vector2i(cx, cz)
            if not tree_cells.has(cell): continue
            for index in tree_cells[cell]:
                var tree: Vector3 = trees[index]
                if Vector2(tree.x - point.x, tree.z - point.z).length_squared() < radius * radius: found.append(index)
    return found

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
    if water_interaction: water_interaction.update(delta)
    collider_clock -= delta
    if collider_clock > 0: return
    collider_clock = 1.0
    var observers: Array[Vector3] = []
    for p in NetworkSession.players.values():
        if NetworkSession.is_host() or p.local_player: observers.append(p.global_position)
    if is_instance_valid(NetworkSession.jeep): observers.append(NetworkSession.jeep.global_position)
    var wanted: Dictionary = {}
    for observer in observers:
        for i in trees_near(observer, 75.0): wanted[i] = true
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
