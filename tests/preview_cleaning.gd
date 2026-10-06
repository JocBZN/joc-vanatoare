extends SceneTree
## The camp hide cleaner in the real Main scene: the machine in the camp, the
## live drum panel mid-session and the cleaned result.
## Run graphically with -- --cleaning-preview-out=C:/absolute/path [--hide=bear_pelt__r5].
## The drum is played by the test bot through the real host, one op per frame.
const Bot=preload("res://tests/harvest_bot.gd")
var scene
var session
var hunter
var output_dir: String="res://work/cleaning_preview"
var hide_id: String="bear_pelt__r5"

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
    for i in count: await process_frame

func capture(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
    print("CLEANING_CAPTURE ",name)

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--cleaning-preview-out="): output_dir=argument.trim_prefix("--cleaning-preview-out=")
        if argument.begins_with("--hide="): hide_id=argument.trim_prefix("--hide=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    root.size=Vector2i(1440,900);root.content_scale_size=root.size
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings")
    locale.cinematic=false;locale.language="ro";TranslationServer.set_locale("ro");locale.changed.emit()
    await frames(20);scene.menu.resume()
    hunter=scene.hunter
    var cleaner
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="cleaner": cleaner=stall
    if cleaner==null: push_error("no cleaner");quit(1);return
    hunter.inventory.backpack_id=&"hoarder";hunter.inventory.items.clear()
    hunter.inventory.items.append(AnimalCatalog.loot(StringName(hide_id)))
    hunter.inventory.changed.emit()
    hunter.global_position=cleaner.interaction_position()+(cleaner.interaction_position()-cleaner.global_position).normalized()*1.5+Vector3.UP*.2
    hunter.visual.rotation.y=atan2(cleaner.global_position.x-hunter.global_position.x,cleaner.global_position.z-hunter.global_position.z)
    hunter.camera_rig.rotation.y=hunter.visual.rotation.y+PI
    await frames(40)
    await capture("curatare_masina")
    hunter.global_position=cleaner.interaction_position()+Vector3.UP*.1
    session.set_physics_process(false);hunter.set_physics_process(false)
    scene._begin_clean();scene._update_clean(0)
    var clock: Dictionary={}
    var shot: bool=false
    var flying_shot: bool=false
    for guard in 4000:
        var state: Dictionary=session.clean_state(1)
        if not bool(state.get("active",false)): break
        if int(clock.get("token",-1))!=int(state.token): clock.token=int(state.token);clock.blade=Vector2(state.blade)
        hunter.command["harvest"]=true;hunter.command["time"]=Time.get_ticks_msec()
        if not flying_shot and float(state.time)<1.9:
            # Let the first volley rise untouched once, so the capture shows it.
            session._tick_cleans(1.0/60.0);scene._update_clean(0);await process_frame
            if float(state.time)>=1.8: flying_shot=true;await capture("curatare_zbor")
            continue
        var ops: Array=Bot.clean_ops(state,Vector2(clock.blade))
        if ops.size()==1 and String(ops[0].kind)=="wait":
            session._tick_cleans(1.0/60.0)
        else:
            for op in ops:
                clock.stamp=int(clock.get("stamp",1000))+int(op.dt);clock.blade=op.p
                session.local_blade=op.p
                session._clean_blade(1,op.p,int(clock.stamp))
            session._tick_cleans(1.0/60.0)
        scene._update_clean(0)
        await process_frame
        if not shot and float(state.time)>8.0 and not scene.cleaning_panel._popups.is_empty():
            shot=true;await capture("curatare_tambur")
    scene._update_clean(0)
    await frames(10)
    await capture("curatare_rezultat")
    print("CLEANING_PREVIEW_DONE items=",hunter.inventory.items.map(func(item): return String(item.id)))
    scene.queue_free();await frames(8);quit(0)
