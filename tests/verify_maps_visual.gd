extends SceneTree
var scene
var session
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame
func snap(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/"+name_value+".png")
func click(point: Vector2) -> void:
    var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move,true)
    var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true;button.position=point;button.global_position=point
    root.push_input(button,true);button=button.duplicate();button.pressed=false;root.push_input(button,true)
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings");locale.set_language("ro")
    scene.menu.resume()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.5)
    scene.hunter.visual.rotation.y=0;scene.hunter.camera_rig.rotation.y=0
    await frames(12);await snap("preview_campfire_interaction")
    var event:=InputEventAction.new();event.action="interact";event.pressed=true
    root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
    if not scene.map_menu.is_open: push_error("FAIL viewport E at fire");quit(1);return
    print("PASS viewport E opens map selection")
    await frames(4);await snap("preview_maps_ro")
    locale.set_language("en");await frames(3);await snap("preview_maps_en")
    click(scene.map_menu.start_button.get_global_rect().get_center())
    if session.phase!="loading": push_error("FAIL viewport map Start click");quit(1);return
    print("PASS viewport map Start enters loading")
    if scene.hunter.combat.shots_fired!=0: push_error("FAIL menu click fired a gun");quit(1);return
    print("PASS map mouse input does not fire")
    for i in 2400:
        if session.phase=="hunt": break
        await process_frame
    for a in session.animals.values(): a.set_physics_process(false)
    scene.hunter.control_enabled=false;scene.hunter.global_position=Vector3(0,.05,-32);scene.hunter.set_physics_process(false)
    var wolf=session.spawn_animal(&"wolf",Vector3(0,0,-38));wolf.take_damage(1,scene.hunter.global_position,1)
    var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(8,4,-31);camera.look_at(Vector3(0,1,-35));camera.current=true
    locale.set_language("ro")
    await frames(45);await snap("preview_predator_attack")
    print("PASS graphical Forest menu and predator chase")
    scene.queue_free();await frames(8);quit()
