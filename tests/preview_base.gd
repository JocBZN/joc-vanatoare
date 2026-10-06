extends SceneTree
## Renders the Mammoth base from the camp and from each floor.
## Usage: godot --path . --script res://tests/preview_base.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(12)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("BASE_SHOT ",name_value)
func shot(name_value: String, from: Vector3, to: Vector3, hunter_at: Vector3=Vector3.INF) -> void:
    if hunter_at!=Vector3.INF: scene.hunter.global_position=hunter_at
    camera.position=from;camera.look_at(to)
    await capture(name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    scene.hunter.control_enabled=false;scene.hunter.set_physics_process(false)
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=700;camera.fov=62
    var base=scene.world_router.active.get_node("MegaBase")
    var o: Vector3=base.global_position
    await shot("base_camp",Vector3(4,7.5,15),o+Vector3(0,6,0),Vector3(30,0,30))
    await shot("base_front",Vector3(-2,4.2,-3),o+Vector3(-1,5.5,0))
    await shot("base_side",Vector3(22,6,-2),o+Vector3(4,5,0))
    # Hunter in front of each keeper so they turn around and talk.
    var weapons: Vector3=base.counters.weapons.interaction_position()
    await shot("base_floor1",weapons+Vector3(2.8,1.7,3.6),weapons+Vector3(-.5,1.2,-2.6),weapons)
    var bags: Vector3=base.counters.backpacks.interaction_position()
    await shot("base_backpacks",bags+Vector3(-2.6,1.6,3.4),bags+Vector3(.3,1.2,-2.6),bags)
    var storage: Vector3=base.counters.storage.interaction_position()
    await shot("base_floor2",storage+Vector3(3.4,1.6,3.3),storage+Vector3(-.6,1.0,-2.6),storage)
    var sell: Vector3=base.counters.sell.interaction_position()
    await shot("base_sell",sell+Vector3(3.6,1.8,4.6),sell+Vector3(-.4,1.4,-2.0),sell)
    await shot("base_roof",o+Vector3(-10,14.5,8),o+Vector3(1,10.4,0),o+Vector3(-3,10.3,3.5))
    await shot("base_scaffold",o+Vector3(-10,5.5,13),o+Vector3(-17,4.5,1),o+Vector3(-16,0,8))
    scene.queue_free();await frames(5);quit()
