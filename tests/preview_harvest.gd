extends SceneTree
## Actual Main scene, corpse interaction, live skinning panel and quality loot.
## Run graphically with -- --harvest-preview-out=C:/absolute/path [--animal=bear].
## The routine is played by the test bot through the real host functions, one
## op per rendered frame, so captures show the genuine trail, popups and knife.
const Bot=preload("res://tests/harvest_bot.gd")
var scene
var session
var hunter
var carcass
var carcass_id: int=0
var camera: Camera3D
var output_dir: String="res://work/harvest_preview"
var kind: StringName=&"bear"

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
    for i in count: await process_frame

func fail(message: String) -> void:
    push_error("Harvest preview: "+message)
    quit(1)

func capture(name: String) -> void:
    await RenderingServer.frame_post_draw
    var error: Error=root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
    if error!=OK: fail("save failed: "+error_string(error));return
    print("HARVEST_CAPTURE ",name," fps=",Engine.get_frames_per_second())

func refresh_intent() -> void:
    hunter.harvest_target=carcass_id
    hunter.control_enabled=true
    hunter.command["harvest"]=true
    hunter.command["direction"]=Vector3.ZERO
    hunter.command["time"]=Time.get_ticks_msec()

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--harvest-preview-out="): output_dir=argument.trim_prefix("--harvest-preview-out=")
        if argument.begins_with("--animal="): kind=StringName(argument.trim_prefix("--animal="))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    root.size=Vector2i(1440,900);root.content_scale_size=root.size
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings")
    locale.cinematic=false;locale.language="ro";TranslationServer.set_locale("ro");locale.changed.emit()
    await frames(20);scene.menu.resume()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    if session.phase!="hunt" or session.world_id!="forest": fail("forest did not load");return

    # Freeze host simulation after genuine travel; animations/UI continue to draw.
    session.set_physics_process(false)
    hunter=scene.hunter;hunter.set_physics_process(false);hunter.control_enabled=true
    hunter.camera_rig.enabled=false;hunter.camera_rig.set_process(false)
    hunter.camera_rig.view_model.hide();hunter.camera_rig.scope_overlay.hide();hunter.visual.hide()
    hunter.inventory.backpack_id=&"hoarder"
    for animal in session.animals.values(): animal.set_physics_process(false)
    var body_point=Vector3(12,session.forest.height_at(12,7)+.03,7)
    hunter.global_position=Vector3(12,session.forest.height_at(12,9.1)+.03,9.1)
    hunter.velocity=Vector3.ZERO
    carcass=session.spawn_animal(kind,body_point)
    if not is_instance_valid(carcass): fail(str(kind)+" spawn failed");return
    carcass_id=carcass.animal_id
    carcass.global_position=body_point;carcass.set_physics_process(false)
    carcass.take_damage(99999,hunter.global_position,1)
    if not carcass.dead: fail("animal did not become a carcass");return
    camera=Camera3D.new();scene.add_child(camera);camera.fov=66;camera.far=900
    camera.position=hunter.global_position+Vector3(.2,1.65,.05)
    camera.look_at(body_point+Vector3(0,.35,0));camera.current=true
    scene.hud.show();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    await frames(35)
    await capture("jupuire_interactiune")

    refresh_intent()
    scene._begin_harvest(carcass)
    await frames(3);scene._update_harvest(0)
    if not scene.harvest_panel.is_open() or not session.is_harvesting(1): fail("live harvest panel did not open");return
    await frames(10)
    await capture("jupuire_inceput")

    var clock: Dictionary={}
    var shots: Dictionary={}
    for guard in 900:
        var state: Dictionary=session.harvest_state(1)
        if not bool(state.get("active",false)): break
        if int(clock.get("token",-1))!=int(state.token): clock.token=int(state.token);clock.blade=Vector2(state.blade)
        for op in Bot.next_ops(state,Vector2(clock.blade)):
            refresh_intent()
            match String(op.kind):
                "wait": session._tick_harvests(.1)
                "blade":
                    clock.stamp=int(clock.get("stamp",1000))+int(op.dt);clock.blade=op.p
                    session.local_blade=op.p
                    session._harvest_blade(1,op.p,int(clock.stamp))
                "click":
                    clock.click=maxi(int(clock.get("click",0)),int(state.get("clicks",0)))+1
                    session._harvest_click(1,"%d:%d:%d:%.5f:%.5f" % [int(state.id),int(state.token),int(clock.click),Vector2(op.p).x,Vector2(op.p).y])
            scene._update_harvest(0)
            await process_frame
            var now: Dictionary=session.harvest_state(1)
            if not bool(now.get("active",false)): break
            var move: int=int(now.move)
            if move==HarvestPattern.MOVE_SLASH and not shots.has("slash") and not scene.harvest_panel._popups.is_empty() and int(now.completed)>=1:
                shots["slash"]=true;await frames(2);await capture("jupuire_taiere")
            if move==HarvestPattern.MOVE_SCRAPE and not shots.has("scrape") and float(now.fat[0])<.6:
                shots["scrape"]=true;await capture("jupuire_razuire")
            if move==HarvestPattern.MOVE_YANK and not shots.has("yank") and bool(now.grabbed) and HarvestPattern.yank_tension(HarvestPattern.yank(int(now.id),int(now.step)).ring,session.local_blade,HarvestPattern.yank(int(now.id),int(now.step)).dir)>.5:
                shots["yank"]=true;await capture("jupuire_smulgere")
            if int(now.round)!=int(state.round): break
    var finished: Dictionary=session.harvest_state(1)
    if bool(finished.get("active",true)) or finished.get("feedback","")!="complete" or session.animals.has(carcass_id):
        fail("quality harvest did not complete/consume the carcass");return
    scene._update_harvest(0)
    await frames(8);await capture("jupuire_calitate")
    var quality_loot: PackedStringArray=PackedStringArray()
    for item in hunter.inventory.items:
        if "__s" in str(item.id): quality_loot.append(str(item.id))
    print("HARVEST_PREVIEW_DONE carcass=",carcass_id," kind=",kind," shots=",shots.keys()," quality_loot=",quality_loot)
    scene.queue_free();await frames(8);quit(0)
