extends SceneTree
var scene
var session
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame
func snap(id: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/art_"+id+".png")
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings");locale.set_language("en")
    await frames(30);await snap("menu")
    scene.menu.resume();scene.hunter.control_enabled=false;scene.hunter.set_physics_process(false)
    camera=Camera3D.new();scene.add_child(camera);camera.current=true
    camera.position=Vector3(12,5,17);camera.look_at(Vector3(0,3,0));await frames(35);await snap("camp")
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4);session.request_action("start_hunt","forest")
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    print("PHASE ",session.phase)
    for a in session.animals.values(): a.set_physics_process(false)
    var p: Vector3=Vector3(12,session.forest.height_at(12,-88)+1,-88)
    scene.hunter.global_position=p
    scene.hunter.camera_rig.enabled=false;camera.current=true
    scene.hunter.hide();scene.hud.hide()
    camera.position=p+Vector3(0,1.8,0);camera.look_at(p+Vector3(14,1,-28))
    await frames(90);await snap("forest")
    var wolf=session.spawn_animal(&"wolf",p+Vector3(8,0,-11));wolf.set_physics_process(false)
    camera.position=wolf.global_position+Vector3(3,2,4);camera.look_at(wolf.global_position+Vector3.UP)
    await frames(35);await snap("wolf")
    print("ART_METRICS fps=",Engine.get_frames_per_second()," objects=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    scene.queue_free();await frames(8);quit()
