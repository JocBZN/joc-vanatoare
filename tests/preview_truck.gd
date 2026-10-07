extends SceneTree
## Renders the Wandering Oak with every upgrade fitted (bull bar, watchtower,
## nitro boosters, boat kit), the garage bench and the garage screen.
## Usage: godot --path . --script res://tests/preview_truck.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var truck
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(12)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("TRUCK_SHOT ",name_value)
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
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=700;camera.fov=62
    for i in 90: await physics_frame
    hunter.global_position=Vector3(-30,0,30)
    for id in TruckUpgrades.ORDER: session.truck_state[String(id)]=TruckUpgrades.max_level(id)
    truck.set_upgrades(session.truck_state)
    await frames(5)
    await shot("truck_front",Vector3(-7.5,4.0,-14.5),Vector3(0,2.6,-6))
    await shot("truck_bench",Vector3(8.0,2.4,-6.0),Vector3(2.0,1.2,-1.9))
    truck.boosting=true
    await frames(40)
    await shot("truck_rear",Vector3(7.5,4.6,15.5),Vector3(0,2.0,6.5))
    truck.boosting=false
    await shot("truck_side",Vector3(-14.5,3.6,2.0),Vector3(0,2.4,0))
    await shot("truck_tower",Vector3(-7.5,13.5,-9.5),Vector3(0,11.0,-.3))
    await shot("truck_overview",Vector3(-16,9.5,-17),Vector3(0,4.8,0))
    # The garage screen, with a wallet to spend.
    hunter.inventory.coins=4200
    session.truck_state=TruckUpgrades.fresh();session.truck_state["speed"]=1;session.truck_state["bar"]=1
    scene.hud.hide()
    scene.garage.open_for(hunter.inventory)
    await capture("garage_screen")
    print("TRUCK_PREVIEW_DONE")
    scene.queue_free();await frames(5);quit()
