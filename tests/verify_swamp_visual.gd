extends SceneTree
var scene
var session
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func snap(name: String,card: bool=false) -> void:
    await RenderingServer.frame_post_draw
    var file="res://assets/ui/swamp_card.png" if card else "res://docs/swamp_"+name+".png"
    root.get_texture().get_image().save_png(file)
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene;session=root.get_node("NetworkSession")
    root.get_node("LocaleSettings").set_language("en");await frames(20);scene.menu.resume()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4);session.request_action("start_hunt","swamp")
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    print("PHASE ",session.phase)
    scene.hunter.set_physics_process(false);scene.hunter.control_enabled=false;scene.hunter.camera_rig.enabled=false
    for a in session.animals.values(): a.set_physics_process(false)
    camera=Camera3D.new();scene.add_child(camera);camera.far=700;camera.current=true
    scene.hud.hide();scene.hunter.visual.hide()
    camera.position=Vector3(20,3.4,-54);camera.look_at(Vector3(39,.8,-105));await frames(125);await snap("landscape");await snap("card",true)
    camera.position=Vector3(120,4,-136);camera.look_at(Vector3(106,2,-157));await frames(100);await snap("hut")
    var p:=Vector3(0,0,-24)
    var crocodile=session.spawn_animal(&"crocodile",p);crocodile.set_physics_process(false);crocodile.rotation.y=.65
    print("CROC_CLIPS ",crocodile.clips," skeletons=",crocodile.model.find_children("*","Skeleton3D",true,false).size())
    camera.position=crocodile.global_position+Vector3(3,1.3,-3);camera.look_at(crocodile.global_position+Vector3(0,.4,0));await frames(90);await snap("crocodile")
    var frog=session.spawn_animal(&"frog",Vector3(0,0,-23));frog.set_physics_process(false)
    crocodile.hide()
    camera.position=frog.global_position+Vector3(.8,.55,-.85);camera.look_at(frog.global_position+Vector3.UP*.2);await frames(50);await snap("frog")
    print("SWAMP_METRICS fps=",Engine.get_frames_per_second()," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    scene.hunter.visual.show();session.request_action("return_lobby")
    for i in 3600:
        if session.phase=="lobby": break
        await process_frame
    camera.current=true;scene.hud.hide();scene.map_menu.open();scene.map_menu.select_map("swamp");await frames(25);await snap("menu")
    scene.queue_free();await frames(8);quit()
