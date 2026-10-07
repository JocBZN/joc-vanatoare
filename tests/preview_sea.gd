extends SceneTree
## Renders every sea creature from the side (cruising, and one attacking), the colossal
## squid in four poses, and a diver in the suit.
## Usage: godot --path . --script res://tests/preview_sea.gd -- [output_dir] [only_species]
var scene
var session
var camera: Camera3D
var ocean
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(10)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("SEA_SHOT ",name_value)
func shot(name_value: String, from: Vector3, to: Vector3) -> void:
    camera.current=true
    camera.global_position=from;camera.look_at(to,Vector3.UP)
    await capture(name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    var only: String=args[1] if args.size()>1 else ""
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    var hunter=scene.hunter
    hunter.control_enabled=false
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=900;camera.fov=60
    for build in ["bar","tower","nitro","boat"]: session.truck_state[build]=1
    session._begin_loading("ocean")
    for i in 7200:
        if session.phase!="loading": break
        await process_frame
    if session.phase!="hunt": push_error("ocean did not load");quit(1);return
    ocean=scene.world_router.active.ocean
    session.spawn_clock=99999.0
    for a in session.animals.values(): a.set_physics_process(false);session.remove_animal(a.animal_id)
    scene.hud.hide()
    var stage:=Vector3(260,-9,-330)
    for i in 40:
        if ocean.water_depth(stage)>40.0: break
        stage+=Vector3(30,0,-20)
    stage.y=-9.0
    print("STAGE ",stage," depth=",ocean.water_depth(stage))
    var kinds: Array=[]
    for entry in AnimalCatalog.OCEAN_ANIMALS: kinds.append(String(entry.id))
    kinds.append("colossal_squid");kinds.append("megalodon")
    for kind in kinds:
        if only!="" and kind!=only: continue
        var a=session.spawn_animal(StringName(kind),stage)
        a.set_physics_process(false)
        a.global_position=stage;a.rotation.y=0.0
        var def: AnimalDefinition=a.definition
        a.velocity=Vector3(0,0,-def.run_speed*.55)
        a.state="Run"
        await frames(8)
        var reach: float=maxf(def.length*1.5,4.5)
        if kind=="colossal_squid":
            a.behavior="Pursue"
            await shot("sea_"+kind+"_hunt",stage+Vector3(26,4,-6),stage+Vector3(-3,0,-3))
            a.state="Attack";a.behavior="Attack";a.attack_sequence+=1
            await frames(24)
            await shot("sea_"+kind+"_strike",stage+Vector3(24,3,-18),stage+Vector3(-4,0,-8))
            a.state="Leap";a.behavior="Leap"
            await frames(10)
            await shot("sea_"+kind+"_jet",stage+Vector3(26,3,-4),stage+Vector3(-2,0,0))
            a.behavior="Ink";a.state="Run"
            await frames(40)
            await shot("sea_"+kind+"_ink",stage+Vector3(28,6,6),stage+Vector3(0,0,2))
        else:
            await shot("sea_"+kind,stage+Vector3(reach,def.length*.12,-def.length*.1),stage)
            if def.aggressive and def.leap_range+def.shock_radius>0:
                a.state="Attack";a.behavior="Attack"
                await shot("sea_"+kind+"_bite",stage+Vector3(reach*.8,def.length*.1,-def.length*.45),stage+Vector3(0,0,-def.length*.2))
        session.remove_animal(a.animal_id)
    if only=="" or only=="diver":
        hunter.global_position=stage+Vector3(0,0,30)
        await frames(30)
        var at: Vector3=hunter.global_position
        await shot("diver_front",at+Vector3(1.0,0.2,-3.2),at+Vector3(0,1.0,0))
    print("SEA_PREVIEW_DONE")
    scene.queue_free();await frames(5);quit()
