extends Node3D
signal build_progress(value: float)
@onready var swamp: SwampMap=$Swamp
var retained_assets: Array[Resource]=[]
var wood: StandardMaterial3D
var labels: Dictionary={}
var atmosphere: Environment

func _ready() -> void:
    wood=GameArt.pbr("rough_wood",2).duplicate() as StandardMaterial3D;wood.albedo_color=Color.WHITE
    var sky_mat:=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color("628a9e");sky_mat.sky_horizon_color=Color("c6d7cc")
    sky_mat.ground_horizon_color=Color("afc9bd");sky_mat.ground_bottom_color=Color("243b3d")
    var sky:=Sky.new();sky.sky_material=sky_mat
    atmosphere=Environment.new();atmosphere.background_mode=Environment.BG_SKY;atmosphere.sky=sky
    atmosphere.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;atmosphere.ambient_light_color=Color("b6cccf");atmosphere.ambient_light_energy=.62
    atmosphere.fog_enabled=true;atmosphere.fog_light_color=Color("a2c3b9");atmosphere.fog_density=.002;atmosphere.fog_height=-1;atmosphere.fog_height_density=.13
    GameArt.cinematic(atmosphere)
    var env:=WorldEnvironment.new();env.environment=atmosphere;add_child(env)
    var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-28,-48,0);sun.light_color=Color("f4dfbc");sun.light_energy=1.05;sun.shadow_enabled=true;sun.directional_shadow_max_distance=120;add_child(sun)
    LocaleSettings.changed.connect(_localize)
    var ambient:=AudioStreamPlayer.new()
    var ambience: AudioStreamWAV=load("res://assets/audio/swamp_ambience.wav").duplicate()
    ambience.loop_mode=AudioStreamWAV.LOOP_FORWARD;ambience.loop_begin=0;ambience.loop_end=roundi(ambience.get_length()*ambience.mix_rate)
    ambient.stream=ambience;ambient.volume_db=-14;add_child(ambient);ambient.play()

func build() -> void:
    swamp.build_progress.connect(func(value: float) -> void: build_progress.emit(value*.84))
    await swamp.build()
    if swamp.cancelled or not is_inside_tree(): return
    _landmarks();_fireflies()
    for entry: AnimalDefinition in AnimalCatalog.SWAMP_ANIMALS+[AnimalCatalog.boss_for("swamp")]:
        retained_assets.append(load(entry.model_path));build_progress.emit(.9)
        await get_tree().process_frame
        if swamp.cancelled or not is_inside_tree(): return
    await get_tree().physics_frame
    build_progress.emit(1)

func _box(parent: Node3D,point: Vector3,size: Vector3,material: Material=null,solid: bool=false) -> MeshInstance3D:
    var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;mesh.material=material if material else wood;node.mesh=mesh;node.position=point;parent.add_child(node)
    if solid:
        var body:=StaticBody3D.new();body.position=point;parent.add_child(body)
        var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
    return node

func _boardwalk(start: Vector3,end: Vector3,width: float=4.6) -> void:
    var root:=Node3D.new();root.name="Boardwalk";root.position=start;add_child(root,true)
    var length:=start.distance_to(end);root.look_at(end)
    _box(root,Vector3(0,-.14,-length*.5),Vector3(width,.28,length),wood,true)
    var boards:=BoxMesh.new();boards.size=Vector3(width,.06,.405);boards.material=wood
    var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=boards;mm.instance_count=ceili(length/.45)
    for i in mm.instance_count: mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,.02,-i*.45)))
    var deck:=MultiMeshInstance3D.new();deck.multimesh=mm;root.add_child(deck)
    for i in ceili(length/4):
        for side in [-1,1]:
            _box(root,Vector3(side*(width*.5+.05),-.55,-i*4),Vector3(.16,2.4,.16))
            _box(root,Vector3(side*(width*.5+.05),.7,-i*4-2),Vector3(.1,.12,4))
    var direction: Vector3=(end-start).normalized()
    var before: Vector3=start-direction*6;var after: Vector3=end+direction*6
    _ramp(root,Vector3(0,swamp.height_at(before.x,before.z)-start.y+.07,6),Vector3(0,.05,0),width)
    _ramp(root,Vector3(0,.05,-length),Vector3(0,swamp.height_at(after.x,after.z)-start.y+.07,-length-6),width)

func _ramp(parent: Node3D,a: Vector3,b: Vector3,width: float) -> void:
    var body:=StaticBody3D.new();parent.add_child(body);body.position=(a+b)*.5;body.quaternion=Quaternion(Vector3.FORWARD,(b-a).normalized())
    var shape:=BoxShape3D.new();shape.size=Vector3(width,.18,a.distance_to(b))
    var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
    _box(body,Vector3.ZERO,shape.size)

func _tag(key: String,point: Vector3) -> void:
    var label:=Label3D.new();label.position=point;label.font_size=34;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=60
    label.modulate=Color("efdbaa");add_child(label);labels[key]=label;label.text=tr(key)

func _lamp(parent: Node3D,point: Vector3) -> void:
    var mat:=StandardMaterial3D.new();mat.albedo_color=Color("fbd899");mat.emission_enabled=true;mat.emission=Color("ffc376");mat.emission_energy_multiplier=2
    _box(parent,point,Vector3(.2,.35,.2),mat)
    var light:=OmniLight3D.new();light.position=point;light.light_color=Color("ffc98a");light.light_energy=1.5;light.omni_range=11;light.distance_fade_enabled=true;light.distance_fade_begin=35;parent.add_child(light)

func _landmarks() -> void:
    _tag("SWAMP_LANDING",Vector3(0,4,3))
    var shelter:=Node3D.new();shelter.name="LandingShelter";shelter.position=Vector3(8,1.15,4);add_child(shelter)
    for x in [-2,2]:
        for z in [-1.5,1.5]: _box(shelter,Vector3(x,1.6,z),Vector3(.18,3.2,.18),wood,true)
    var tarp:=GameArt.pbr("fabric_pattern_07",3).duplicate() as StandardMaterial3D;tarp.albedo_color=Color("78934e");_box(shelter,Vector3(0,3.2,0),Vector3(4.7,.15,3.8),tarp)
    _lamp(shelter,Vector3(-1.8,2.6,0))
    _box(shelter,Vector3(0,.5,-.8),Vector3(2,.95,.7),wood,true)
    _boardwalk(Vector3(20,1.36,24),Vector3(20,1.36,-165))
    _boardwalk(Vector3(20,1.36,-155),Vector3(112,1.36,-155))
    _boardwalk(Vector3(-5,1.36,-95),Vector3(-155,1.36,-100))
    var hut:=Node3D.new();hut.name="AbandonedHut";hut.position=Vector3(110,.9,-155);add_child(hut)
    _box(hut,Vector3(0,.25,0),Vector3(8,.5,7),wood,true)
    for x in [-3.5,3.5]:
        for z in [-2.7,2.7]: _box(hut,Vector3(x,2.1,z),Vector3(.24,4.2,.24),wood,true)
    _box(hut,Vector3(0,2.2,-3),Vector3(7.5,3.9,.18),wood,true)
    _box(hut,Vector3(-3.7,2.2,0),Vector3(.18,3.9,6),wood,true)
    var roof:=_box(hut,Vector3(0,4.2,0),Vector3(8.6,.2,7.8));roof.rotation.z=.08
    _lamp(hut,Vector3(2.8,3.2,-2.6));_tag("SWAMP_HUT",hut.position+Vector3(0,5,0))
    var tower:=Node3D.new();tower.name="OldWatchtower";tower.position=Vector3(-155,.9,-100);add_child(tower)
    for x in [-2,2]:
        for z in [-2,2]: _box(tower,Vector3(x,2.9,z),Vector3(.3,5.8,.3),wood,true)
    _box(tower,Vector3(0,5.8,0),Vector3(5,.25,5),wood,true)
    _box(tower,Vector3(0,8.4,0),Vector3(5.8,.18,5.8))
    for i in 25: _box(tower,Vector3(3.5,i*.22,-4.8+i*.39),Vector3(1.7,.22,.42),wood,true)
    _box(tower,Vector3(2.8,5.6,3.2),Vector3(3,.25,3.5),wood,true)
    _ramp(tower,Vector3(3.5,.15,-4.95),Vector3(3.5,5.65,4.95),1.7)
    _tag("SWAMP_TOWER",tower.position+Vector3(0,8.8,0));_lamp(tower,Vector3(1.8,6.8,1.8))
    var lair:=Node3D.new();lair.name="CrocodileLair";lair.position=Vector3(170,.15,-330);add_child(lair)
    for i in 8:
        var rock:=MeshInstance3D.new();rock.mesh=GameArt.nature_mesh("rock_"+str(i%3));rock.position=Vector3(sin(i)*7,-.2,cos(i)*7);rock.scale=Vector3.ONE*2;rock.rotation.y=i; lair.add_child(rock)
    _tag("SWAMP_LAIR",lair.position+Vector3.UP*3)
    # Additional fallen trunks create cover without blocking the arrival road.
    for point in [Vector3(42,0,-60),Vector3(-43,0,-140),Vector3(80,0,-220)]:
        var trunk:=MeshInstance3D.new();trunk.mesh=GameArt.nature_mesh("swamp_dead_tree");trunk.position=point;trunk.position.y=swamp.height_at(point.x,point.z)+.45;trunk.rotation.z=PI*.47;trunk.scale=Vector3.ONE*.65;add_child(trunk)

func _fireflies() -> void:
    var particles:=GPUParticles3D.new();particles.name="Fireflies";particles.position=Vector3(0,1,-80);particles.amount=130;particles.lifetime=12;particles.preprocess=6;particles.visibility_aabb=AABB(Vector3(-120,-4,-180),Vector3(240,14,280))
    var material:=ParticleProcessMaterial.new();material.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;material.emission_box_extents=Vector3(100,2,130);material.gravity=Vector3.ZERO;material.initial_velocity_min=.15;material.initial_velocity_max=.35;material.direction=Vector3.UP;material.spread=180
    material.scale_min=.018;material.scale_max=.05;particles.process_material=material
    var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=6;mesh.rings=3
    var glow:=StandardMaterial3D.new();glow.albedo_color=Color("d0df7e");glow.emission_enabled=true;glow.emission=Color("d0df7e");glow.emission_energy_multiplier=2;mesh.material=glow;particles.draw_pass_1=mesh;add_child(particles)

func _localize() -> void:
    for key in labels: labels[key].text=tr(key)
    GameArt.cinematic(atmosphere)
