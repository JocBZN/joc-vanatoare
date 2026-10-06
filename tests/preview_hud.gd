extends SceneTree
## Renders the new HUD and maps in a real expedition: on foot near a boss, the
## big map (M), at the wheel with the speedometer, riding the terrace, and the
## swamp map with its albino crocodile.
## Usage: godot --path . --script res://tests/preview_hud.gd -- [output_dir] [forest|swamp]
var scene
var session
var out: String="res://docs"
var map_id: String="forest"
## Who is driving and how: fed every physics frame, also while a shot renders.
var feed: Dictionary={"peer":0,"seq":95000,"drive":Vector2.ZERO}
func _initialize() -> void: call_deferred("run")
func _feed() -> void:
    if int(feed.peer)==0 or session==null: return
    feed.seq=int(feed.seq)+1
    session._accept_input(int(feed.peer),{"seq":int(feed.seq),"direction":Vector3.ZERO,"drive":feed.drive,"yaw":0,"pitch":0})
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(12)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("HUD_SHOT ",name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()>0: out=args[0]
    if args.size()>1: map_id=args[1]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    physics_frame.connect(_feed)
    await frames(15);scene.menu.resume()
    var hunter=scene.hunter
    var truck=session.jeep
    for i in 60: await physics_frame
    hunter.global_position=truck.exit_point(0);truck.enter(1)
    session.request_action("start_hunt",map_id)
    var started: int=Time.get_ticks_msec()
    scene.world_router.progress.connect(func(value: float) -> void: print("LOAD %.2f at %d ms" % [value,Time.get_ticks_msec()-started]))
    for i in 4000:
        if session.phase=="hunt": break
        await process_frame
    print("LOADED after %d ms" % (Time.get_ticks_msec()-started))
    if session.phase!="hunt": push_error("map did not load");quit(1);return
    await frames(30)
    scene.map_menu.close();scene._on_continue()
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    for a in session.animals.values(): a.set_physics_process(false)
    var catalog=load("res://data/animal_catalog.gd")
    # A boss close by, wounded, plus a few animals around for the radar.
    var boss=session.spawn_boss()
    if boss==null: boss=session.spawn_animal(catalog.boss_for(map_id).id,truck.global_position+Vector3(-40,0,-60))
    var near: Vector3=truck.global_position+Vector3(-26,0,-42)
    boss.global_position=Vector3(near.x,session.forest.height_at(near.x,near.z)+.1,near.z);boss.set_physics_process(false)
    boss.health=int(boss.definition.max_health*.62)
    for kind in catalog.population(map_id).slice(0,4):
        var spot: Vector3=truck.global_position+Vector3(randf_range(-80,80),0,randf_range(-90,40))
        var animal=session.spawn_animal(kind.id,spot);if animal: animal.set_physics_process(false)
    truck.exit_seat(1,true)
    hunter.global_position=truck.global_position+Vector3(-6,0,-16);hunter.global_position.y=session.forest.height_at(hunter.global_position.x,hunter.global_position.z)+.2
    hunter.health=64;hunter.inventory.coins=1250
    hunter.inventory.collect(catalog.loot(&"deer_pelt__r4"));hunter.inventory.collect(catalog.loot(&"ancient_bear_claw"))
    # Look at the wounded boss across the clearing.
    var to_boss: Vector3=boss.global_position-hunter.global_position
    hunter.camera_rig.rotation=Vector3(-.08,atan2(-to_boss.x,-to_boss.z),0)
    hunter.visual.rotation.y=hunter.camera_rig.rotation.y
    await frames(40)
    scene._show_feedback(session._message("BOSS_SPAWNED",{"item_key":boss.definition.display_name}))
    scene.hud_view.hit(36)
    await capture("hud_"+map_id+"_foot")
    scene.minimap.toggle_detail()
    await frames(20)
    await capture("hud_"+map_id+"_map")
    scene.minimap.close_detail()
    # At the wheel: speedometer and a zoomed-out radar.
    hunter.global_position=truck.exit_point(0);truck.enter(1)
    feed.peer=1;feed.drive=Vector2(0,-1)
    for i in 150: await physics_frame
    await capture("hud_"+map_id+"_drive")
    feed.peer=0
    # A friend drives on while we ride the terrace.
    var friend=session._spawn_player(2,"Ana");friend.world_ready=true
    truck.linear_velocity=Vector3.ZERO;truck.angular_velocity=Vector3.ZERO
    truck.exit_seat(1,true)
    friend.global_position=truck.exit_point(0);truck.enter(2)
    hunter.place_aboard(truck.to_global(truck.DECK_LANDING))
    feed.peer=2;feed.drive=Vector2(.15,-1)
    for i in 120: await physics_frame
    hunter.camera_rig.rotation=Vector3(-.2,truck.global_rotation.y+2.3,0)
    await capture("hud_"+map_id+"_ride")
    feed.peer=0
    print("HUD_PREVIEW_DONE riding=",hunter.riding," local=",truck.to_local(hunter.global_position).snapped(Vector3.ONE*.01)," speed=",snappedf(truck.speed,.1))
    scene.queue_free();await frames(5);quit()
