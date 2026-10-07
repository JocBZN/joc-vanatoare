extends SceneTree
## Renders the ocean map: the camp island, the open sea from the surface, a reef,
## a kelp forest, a wreck and the minimap, with the camera placed freely.
## Usage: godot --path . --script res://tests/preview_ocean.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var world
var ocean
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(14)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("OCEAN_SHOT ",name_value)
func shot(name_value: String, from: Vector3, to: Vector3) -> void:
    camera.current=true
    camera.global_position=from;camera.look_at(to,Vector3.UP)
    await capture(name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    var hunter=scene.hunter
    hunter.control_enabled=false;hunter.set_physics_process(false)
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=1800;camera.fov=65
    # Load the ocean the same way a hunt does.
    session.truck_state["boat"]=1
    var started: int=Time.get_ticks_msec()
    session._begin_loading("ocean")
    for i in 7200:
        if session.phase!="loading": break
        await process_frame
    print("OCEAN_LOAD_MS ",Time.get_ticks_msec()-started," phase=",session.phase)
    if session.phase!="hunt": push_error("ocean did not load");quit(1);return
    world=scene.world_router.active;ocean=world.ocean
    print("OCEAN_FLORA ",ocean.flora_counts," islands=",ocean.islands.size()," landmarks=",ocean.landmarks.size()," trees=",ocean.trees.size())
    for a in session.animals.values(): a.set_physics_process(false)
    scene.hud.hide()
    await frames(20)
    var jeep=session.jeep
    print("TRUCK at ",jeep.global_position)
    await shot("ocean_camp",Vector3(-26,9,-40),Vector3(8,3,-4))
    await shot("ocean_horizon",Vector3(-8,3.2,-98),Vector3(40,1.0,-210))
    await shot("ocean_pier",Vector3(70,9,40),Vector3(80,0,14))
    # Under the surface off the camp island's shelf.
    var reef: Vector3=Vector3(0,-6,-150)
    var nearest: float=INF
    for spot in ocean.reef_spots:
        var d: float=Vector2(spot.x,spot.z).length()
        if d>150.0 and d<nearest and spot.y<-3.0: nearest=d;reef=spot
    print("REEF ",reef)
    await shot("ocean_reef_above",reef+Vector3(-14,14,-14),reef)
    await shot("ocean_reef",reef+Vector3(-9,1.8,-9),reef+Vector3(0,.8,0))
    await shot("ocean_reef_wide",reef+Vector3(-26,4.0,-20),reef+Vector3(0,1.0,0))
    await shot("ocean_kelp",ocean.kelp_spot+Vector3(-7,3.0,-7),ocean.kelp_spot+Vector3(0,5.0,0))
    for landmark in ocean.landmarks:
        var at: Vector3=landmark.at
        print("LANDMARK ",landmark.key," ",at)
        if landmark.key=="OCEAN_WRECK":
            await shot("ocean_wreck",at+Vector3(-26,9,-26),at+Vector3(0,3,0))
            break
    for landmark in ocean.landmarks:
        if landmark.key=="OCEAN_LIGHTHOUSE":
            var at: Vector3=landmark.at
            await shot("ocean_lighthouse",at+Vector3(-90,14,-90),at+Vector3(0,14,0))
            break
    print("OCEAN_PREVIEW_DONE")
    scene.queue_free();await frames(5);quit()
