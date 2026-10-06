extends SceneTree
## Real project scenes, reproducible lake/swamp water and wake screenshots.
## Run graphically with -- --water-preview-out=C:/absolute/path.
var scene
var session
var camera: Camera3D
var output_dir: String="res://work/water_preview"

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
    for i in count: await process_frame

func capture(name: String) -> void:
    await RenderingServer.frame_post_draw
    var error: Error=root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
    if error!=OK:
        push_error("Water preview save failed: "+error_string(error));quit(1)
    print("WATER_CAPTURE ",name," fps=",Engine.get_frames_per_second()," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))

func travel(map_id: String) -> bool:
    if session.phase=="hunt":
        session.request_action("return_lobby","")
        for i in 3600:
            if session.phase=="lobby": break
            await process_frame
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt",map_id)
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    if session.phase!="hunt" or session.world_id!=map_id:
        push_error("Water preview failed to load "+map_id);return false
    scene.hunter.set_physics_process(false);scene.hunter.control_enabled=false;scene.hunter.camera_rig.enabled=false
    for animal in session.animals.values(): animal.set_physics_process(false)
    scene.hunter.visual.hide();scene.hud.hide();camera.current=true
    return true

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--water-preview-out="): output_dir=argument.trim_prefix("--water-preview-out=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    root.size=Vector2i(1440,900);root.content_scale_size=root.size
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings");locale.cinematic=false;locale.changed.emit()
    await frames(20);scene.menu.resume()
    camera=Camera3D.new();scene.add_child(camera);camera.far=1100;camera.fov=63
    if not await travel("forest"): quit(1);return
    scene.hunter.global_position=Vector3(0,1,0)
    camera.position=Vector3(166,1.6,218);camera.look_at(Vector3(194,-2.9,166))
    await frames(90);await capture("apa_lac")
    camera.position=Vector3(244,26,215);camera.look_at(Vector3(187,-3,166))
    await frames(30);await capture("apa_lac_de_sus")
    # A steep, close angle reveals the real sand bed through the existing surface.
    camera.position=Vector3(190,-.8,162);camera.look_at(Vector3(190,session.forest.height_at(190,160),160))
    await frames(30);await capture("apa_nisip")
    # Real moving hunter positions drive the interaction helper; no synthetic shader event.
    camera.position=Vector3(191,.7,171);camera.look_at(Vector3(191,-3,159))
    var start=Vector3(190,session.forest.height_at(190,160)+.03,160)
    scene.hunter.global_position=start
    for i in 36:
        scene.hunter.global_position=start+Vector3(0,0,-i*.045)
        scene.hunter.velocity=Vector3(0,0,-2.7)
        await process_frame
    scene.hunter.velocity=Vector3.ZERO
    await frames(9);await capture("apa_unde")
    if not await travel("swamp"): quit(1);return
    # Find a real water patch with space around it, independent of the session's random seed.
    var wet=Vector3(45,0,-90);var best_depth: float=0.0
    for x in range(38,120,4):
        for z in range(-160,-50,4):
            var point=Vector3(x,0,z)
            var depth: float=session.forest.water_depth(point)
            var patch_depth: float=depth
            for offset in [Vector3(4,0,0),Vector3(-4,0,0),Vector3(0,0,4),Vector3(0,0,-4),Vector3(0,0,-8)]:
                patch_depth=minf(patch_depth,session.forest.water_depth(point+offset))
            if patch_depth>best_depth and depth<1.25:
                wet=point;best_depth=patch_depth
    scene.hunter.global_position=Vector3(0,1.2,0)
    camera.position=wet+Vector3(13,4.1,18);camera.look_at(wet+Vector3(0,.02,-4))
    await frames(90);await capture("apa_mlastina")
    # Keep the marsh surface enabled: this is mud viewed through actual water.
    camera.position=wet+Vector3(0,1.7,1.5)
    camera.look_at(Vector3(wet.x,session.forest.height_at(wet.x,wet.z),wet.z-1.1))
    await frames(30);await capture("apa_noroi")
    print("WATER_PREVIEW_DONE")
    scene.queue_free();await frames(8);quit(0)
