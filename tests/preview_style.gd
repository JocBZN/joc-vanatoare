extends SceneTree
## Reproduce the three environment previews after changing the art direction.
var scene
var session
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(path: String) -> void:
    await frames(12)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    scene.hunter.control_enabled=false;scene.hunter.set_physics_process(false)
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=700
    camera.position=Vector3(12,5,17);camera.look_at(Vector3(0,3,0))
    await capture("res://docs/art_camp.png")
    for map_id in ["forest","swamp"]:
        if session.phase!="lobby":
            session.request_action("return_lobby")
            for i in 3600:
                if session.phase=="lobby": break
                await process_frame
        var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
        session.request_action("start_hunt",map_id)
        for i in 3600:
            if session.phase=="hunt": break
            await process_frame
        if session.phase!="hunt": push_error("Preview loading failed: "+map_id);quit(1);return
        scene.hunter.camera_rig.enabled=false;scene.hunter.hide();scene.hud.hide();camera.current=true
        if map_id=="forest":
            var point:=Vector3(12,session.forest.height_at(12,-88)+2.8,-88)
            scene.hunter.global_position=point;camera.position=point;camera.look_at(point+Vector3(14,-.8,-28))
            await capture("res://docs/art_forest.png")
        else:
            camera.position=Vector3(20,3.4,-54);camera.look_at(Vector3(39,.8,-105))
            await capture("res://docs/swamp_landscape.png")
        await capture("res://assets/ui/"+map_id+"_card.png")
        print("PREVIEW_OK ",map_id)
    scene.queue_free();await frames(5);quit()
