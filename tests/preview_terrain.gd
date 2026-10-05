extends SceneTree
## One-off visual QA for the new mountain/hill/lake terrain shaping; not part of the shipped suite.
var scene
var session

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame

func capture(path: String) -> void:
    await frames(6)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)
    print("SAVED ", path)

func run() -> void:
    root.size = Vector2i(1920, 1080)
    root.content_scale_size = Vector2i(1920, 1080)
    scene = load("res://game/main.tscn").instantiate()
    root.add_child(scene); current_scene = scene
    session = root.get_node("NetworkSession")
    scene.menu.resume()
    await frames(6)
    var fire = scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position = fire.global_position + Vector3(0, .5, 3.4)
    session.request_action("start_hunt", "forest")
    for i in 2400:
        if session.phase != "loading": break
        await process_frame
    await frames(20)
    var camera := Camera3D.new(); root.add_child(camera); camera.current = true
    # Wide aerial sweep over the new mountain belt, well past the camp fade zone.
    camera.position = Vector3(40, 170, 520)
    camera.look_at(Vector3(200, 20, 150), Vector3.UP)
    camera.far = 1400
    await capture("res://work/weapon_sources/terrain_forest_mountains.png")
    camera.position = Vector3(260, 60, 260)
    camera.look_at(Vector3(190, -2, 160), Vector3.UP)
    await capture("res://work/weapon_sources/terrain_forest_lake.png")
    session.request_action("return_lobby", "")
    for i in 600:
        if session.phase != "loading": break
        await process_frame
    await frames(10)
    fire = scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position = fire.global_position + Vector3(0, .5, 3.4)
    session.request_action("start_hunt", "swamp")
    for i in 2400:
        if session.phase != "loading": break
        await process_frame
    await frames(20)
    camera.position = Vector3(60, 190, 650)
    camera.look_at(Vector3(100, 30, 420), Vector3.UP)
    await capture("res://work/weapon_sources/terrain_swamp_margins.png")
    print("TERRAIN_PREVIEW_DONE")
    quit(0)
