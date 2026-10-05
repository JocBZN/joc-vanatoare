class_name SwampMap
extends ForestMap
## Same deterministic world/streaming contract, a distinct wetland height field.
const SWAMP_SEED=28641
const WATER_LEVEL: float=0.0
const POIS=[Vector2(110,-155),Vector2(-155,-100),Vector2(170,-330)]
var water_material: ShaderMaterial
var plant_meshes: Dictionary={}

func _ready() -> void:
    super._ready()
    noise.seed=SWAMP_SEED;noise.frequency=.008

func height_at(x: float,z: float) -> float:
    var point:=Vector2(x,z)
    var height: float=noise.get_noise_2d(x,z)*1.55+sin(x*.023+cos(z*.016))*.47-.22
    var road: float=1-smoothstep(5.8,11.5,absf(x-sin(z*.008)*28))
    height=lerpf(height,1.05,road)
    for place in POIS.slice(0,2): height=lerpf(height,.9,1-smoothstep(12,30,point.distance_to(place)))
    return lerpf(1.15,height,smoothstep(28,56,point.length()))

func water_depth(point: Vector3) -> float: return maxf(0,WATER_LEVEL-height_at(point.x,point.z))
func route_clear(point: Vector2,margin: float=3.2) -> bool:
    for segment in [[Vector2(20,24),Vector2(20,-165)],[Vector2(20,-155),Vector2(112,-155)],[Vector2(-5,-95),Vector2(-155,-100)]]:
        var a: Vector2=segment[0];var b: Vector2=segment[1]
        var nearest: Vector2=a+(b-a)*clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
        if point.distance_to(nearest)<margin: return true
    return false
func mud_factor(point: Vector3) -> float:
    # Raised wooden walkways remain firm; shallow ground is soft and water adds drag.
    if point.y>1.45: return 0
    return 1-smoothstep(-.65,.8,height_at(point.x,point.z))
func animal_spawn(entry: AnimalDefinition,point: Vector3) -> Vector3:
    var best:=point
    for i in 20:
        var p:=point+Vector3(sin(i*2.4),0,cos(i*2.4))*i*3
        p.x=clampf(p.x,-580,580);p.z=clampf(p.z,-580,580)
        var h:=height_at(p.x,p.z)
        if (entry.aquatic and h<.15) or (not entry.aquatic and h>.2): best=p;break
    best.y=height_at(best.x,best.z)+.12
    if entry.aquatic and best.y<-.1: best.y=-.08
    return best

func _terrain() -> void:
    await super._terrain()
    if cancelled or not is_inside_tree(): return
    var ground: MeshInstance3D=get_child(0)
    var mat:=ShaderMaterial.new();mat.shader=load("res://world/swamp/swamp_ground.gdshader")
    mat.set_shader_parameter("mud_color",GameArt.texture("brown_mud_03","diff"))
    mat.set_shader_parameter("mud_normal",GameArt.texture("brown_mud_03","nor_gl"))
    mat.set_shader_parameter("mud_rough",GameArt.texture("brown_mud_03","arm"))
    mat.set_shader_parameter("bank_color",GameArt.texture("forest_ground_04","diff"))
    mat.set_shader_parameter("bank_normal",GameArt.texture("forest_ground_04","nor_gl"))
    ground.material_override=mat
    water_material=ShaderMaterial.new();water_material.shader=load("res://world/swamp/swamp_water.gdshader")
    water_material.set_shader_parameter("normal_map",GameArt.texture("brown_mud_03","nor_gl"))
    var water:=MeshInstance3D.new();water.name="Water"
    var plane:=PlaneMesh.new();plane.size=Vector2(SIZE,SIZE);plane.subdivide_width=100;plane.subdivide_depth=100
    water.mesh=plane;water.material_override=water_material;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)

func _trees() -> void:
    var rng:=RandomNumberGenerator.new();rng.seed=SWAMP_SEED
    var chunks: Dictionary={}
    for i in 3900:
        if i%500==0:
            build_progress.emit(.62+.16*i/3900.0);await get_tree().process_frame
            if cancelled or not is_inside_tree(): return
        var x:=rng.randf_range(-585,585);var z:=rng.randf_range(-585,585)
        if Vector2(x,z).length()<34 or absf(x-sin(z*.008)*28)<8 or route_clear(Vector2(x,z),4.4): continue
        var near_poi:=false
        for poi in POIS:
            if Vector2(x,z).distance_to(poi)<15: near_poi=true
        if near_poi: continue
        var point:=Vector3(x,height_at(x,z),z);trees.append(point)
        var kind: int=1 if rng.randf()<.34 else 0
        var key:=Vector3i(floori(x/64),floori(z/64),kind)
        if not chunks.has(key): chunks[key]=[]
        chunks[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.65,1.25)),point))
    for key in chunks:
        var id: String="swamp_dead_tree" if key.z==1 else "swamp_tree"
        _multimesh(GameArt.nature_mesh(id),chunks[key],125,0,true)
        _multimesh(GameArt.impostor(id),chunks[key],360,120,false)
    _prepare_plants()
    build_progress.emit(.99)

func _prepare_plants() -> void:
    var green:=GameArt.pbr("forest_ground_04",2).duplicate() as StandardMaterial3D
    green.albedo_texture=null;green.albedo_color=Color("405232");green.cull_mode=BaseMaterial3D.CULL_DISABLED
    var stalk:=CylinderMesh.new();stalk.top_radius=.012;stalk.bottom_radius=.02;stalk.height=1.7;stalk.radial_segments=6;stalk.material=green
    plant_meshes.stalk=stalk
    var flower:=CapsuleMesh.new();flower.radius=.05;flower.height=.32;flower.radial_segments=8;flower.rings=4
    var brown:=green.duplicate() as StandardMaterial3D;brown.albedo_color=Color("46311e");flower.material=brown;plant_meshes.flower=flower
    var leaf_mat:=ShaderMaterial.new();leaf_mat.shader=load("res://art/reed.gdshader")
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for section in 6:
        for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
            var t: float=(section+offset.y)/6.0
            st.set_uv(Vector2(offset.x,t))
            st.add_vertex(Vector3((offset.x-.5)*.105*(1-t),t*1.25,t*t*.34))
    st.generate_normals();var leaf:=st.commit();leaf.surface_set_material(0,leaf_mat);plant_meshes.leaf=leaf
    var lily:=CylinderMesh.new();lily.top_radius=.28;lily.bottom_radius=.28;lily.height=.012;lily.radial_segments=12
    var lily_mat:=green.duplicate() as StandardMaterial3D;lily_mat.albedo_color=Color("496737");lily_mat.roughness=.48;lily.material=lily_mat;plant_meshes.lily=lily

func _plant_sector(key: Vector2i) -> void:
    if plant_meshes.is_empty(): _prepare_plants()
    var rng:=RandomNumberGenerator.new();rng.seed=SWAMP_SEED+key.x*73856093+key.y*19349663
    var groups: Dictionary={}
    for i in 360:
        var x: float=(key.x+rng.randf())*PLANT_SECTOR;var z: float=(key.y+rng.randf())*PLANT_SECTOR
        if Vector2(x,z).length()<22 or absf(x-sin(z*.008)*28)<6.5 or route_clear(Vector2(x,z)): continue
        var h:=height_at(x,z);var yaw:=rng.randf()*TAU;var scale_factor:=rng.randf_range(.7,1.25)
        if h<-.48:
            if i%4==0: _group(groups,"lily",Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor),Vector3(x,.03,z)))
            continue
        if h<.12 and noise.get_noise_2d(x*5,z*5)>.04:
            _group(groups,"stalk",Transform3D(Basis(Vector3.UP,yaw).rotated(Vector3.FORWARD,rng.randf_range(-.13,.13)),Vector3(x,h+.85,z)))
            _group(groups,"flower",Transform3D(Basis(Vector3.UP,yaw),Vector3(x,h+1.65,z)))
            for angle in [0,2.1,4.2]: _group(groups,"leaf",Transform3D(Basis(Vector3.UP,yaw+angle).rotated(Vector3.RIGHT,-.3),Vector3(x,h+.65,z)))
        elif h>.12:
            var id: String="fern_0" if i%30==0 else "grass_patch_small_a" if i%3==0 else "grass_3"
            _group(groups,id,Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*(rng.randf_range(1.3,2) if id.begins_with("fern") else rng.randf_range(3,5))),Vector3(x,h,z)))
    vegetation[key]=[]
    for kind in groups:
        var mesh: Mesh=plant_meshes[kind] if plant_meshes.has(kind) else GameArt.nature_mesh(kind)
        vegetation[key].append(_multimesh(mesh,groups[kind],100,0,false))

func _group(groups: Dictionary,id: String,transform: Transform3D) -> void:
    if not groups.has(id): groups[id]=[]
    groups[id].append(transform)

func _process(delta: float) -> void:
    super._process(delta)
    if water_material:
        var hunter=NetworkSession.local_hunter()
        if is_instance_valid(hunter): water_material.set_shader_parameter("observer",hunter.global_position)
