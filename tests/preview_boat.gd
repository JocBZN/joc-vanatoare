extends SceneTree
## The boat kit's transformation: folded on land, then three moments of the unfold,
## fully deployed on the water, plus the nitro rack from behind.
## Usage: godot --path . --script res://tests/preview_boat.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var truck
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(3)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("BOAT_SHOT ",name_value)
func shot(name_value: String, from: Vector3, to: Vector3) -> void:
    camera.current=true
    camera.global_position=truck.to_global(from);camera.look_at(truck.to_global(to),Vector3.UP)
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
    truck=session.jeep
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=900;camera.fov=62
    for i in 60: await physics_frame
    hunter.global_position=Vector3(-30,0,30)
    for id in TruckUpgrades.ORDER: session.truck_state[String(id)]=TruckUpgrades.max_level(id)
    truck.set_upgrades(session.truck_state)
    truck.freeze=true
    await frames(5)
    # Folded away on land.
    await shot("boat_0_folded",Vector3(-12,3.5,-11),Vector3(0,2.2,-1))
    # The unfold, in three beats, from the same camera.
    var beats: Array=[["boat_1_unfolding",.3],["boat_2_unfolding",.6],["boat_3_deployed",1.0]]
    for beat in beats:
        truck.boat_deploy=beat[1];truck._deploy_shown=beat[1]
        truck._builder.animate_boat(beat[1])
        await shot(beat[0],Vector3(-12,3.5,-11),Vector3(0,2.2,-1))
    await shot("boat_4_side",Vector3(-15,3.0,1.5),Vector3(0,1.6,0))
    await shot("boat_5_rear",Vector3(9,4.5,15.5),Vector3(0,1.8,5.5))
    truck.boosting=true
    await frames(40)
    await shot("boat_6_nitro",Vector3(8,3.2,14),Vector3(0,1.6,6.6))
    print("BOAT_PREVIEW_DONE")
    scene.queue_free();await frames(5);quit()
