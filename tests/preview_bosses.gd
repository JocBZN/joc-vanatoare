extends SceneTree
## Renders both bosses up close in a neutral setting, plus their trophies.
## Usage: godot --path . --script res://tests/preview_bosses.gd -- [output_dir]
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(10)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("BOSS_SHOT ",name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    var stage:=Node3D.new();root.add_child(stage)
    var env:=WorldEnvironment.new();env.environment=Environment.new()
    var sky_material:=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("609bc3");sky_material.sky_horizon_color=Color("d6e4df")
    var sky:=Sky.new();sky.sky_material=sky_material
    env.environment.background_mode=Environment.BG_SKY;env.environment.sky=sky
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b8ccd9");env.environment.ambient_light_energy=.45
    env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    env.environment.fog_enabled=true;env.environment.fog_light_color=Color("bbcfd0");env.environment.fog_density=.006
    stage.add_child(env)
    var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.0;sun.shadow_enabled=true;stage.add_child(sun)
    var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(160,160);ground.mesh=plane
    var mat:=StandardMaterial3D.new();mat.albedo_color=Color("3f5a2e");mat.roughness=1.0;ground.material_override=mat;stage.add_child(ground)
    var camera:=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=50
    var session=root.get_node("NetworkSession")
    session.phase="lobby"
    var wild=load("res://actors/animals/wildlife_animal.gd")
    var catalog=load("res://data/animal_catalog.gd")
    for kind in ["ancient_bear","albino_crocodile"]:
        var animal=wild.new();animal.definition=catalog.animal(StringName(kind));animal.animal_id=7
        stage.add_child(animal);animal.set_physics_process(false)
        animal.rotation.y=-.6
        await frames(5)
        if kind=="ancient_bear":
            camera.position=Vector3(9.6,4.6,-7.4);camera.look_at(Vector3(0,2.0,-1.0))
            await capture("boss_"+kind)
            camera.position=Vector3(-10.5,7.5,2.5);camera.look_at(Vector3(0,3.2,0))
            await capture("boss_"+kind+"_back")
        else:
            camera.position=Vector3(7.0,3.0,-4.5);camera.look_at(Vector3(-.5,.6,-1.2))
            await capture("boss_"+kind)
            camera.position=Vector3(-6.5,4.2,4.0);camera.look_at(Vector3(0,.7,.4))
            await capture("boss_"+kind+"_back")
        animal.queue_free();await frames(3)
    # Trophies laid out in a row, under a softer late-afternoon light so their
    # own gold glow and colours read (the full sun washes them out).
    sun.light_energy=.55;env.environment.ambient_light_energy=.3
    var x: float=-2.75
    for id in catalog.TROPHY_IDS:
        var pickup=load("res://world/pickups/deer_loot.tscn").instantiate()
        pickup.loot_definition=catalog.loot(id);pickup.position=Vector3(x,0,0);stage.add_child(pickup);x+=1.1
    camera.position=Vector3(0,1.5,4.4);camera.look_at(Vector3(0,.3,0))
    await capture("boss_trophies")
    quit()
