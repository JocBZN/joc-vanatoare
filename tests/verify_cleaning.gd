extends SceneTree
## The camp hide cleaner through the real host API and inventory: raw hides go
## in, blade samples go through _accept_input, and cleaned hides come out.
const Bot=preload("res://tests/harvest_bot.gd")
var scene
var session
var hunter
var cleaner
var checks: int=0
var failures: int=0
var sequence: int=70000
var clock: Dictionary={}
var dirt_before: int=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await process_frame
func active() -> Dictionary:
    var state: Dictionary=session.clean_state(1)
    return state if bool(state.get("active",false)) else {}
func focus() -> void:
    sequence+=1
    session._accept_input(1,{"seq":sequence,"direction":Vector3.FORWARD,"drive":Vector2.UP,"yaw":0,"pitch":0,"harvest":true})
func blade(point: Vector2, stamp: int) -> void:
    sequence+=1
    clock.stamp=stamp;clock.blade=point
    session._accept_input(1,{"seq":sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"harvest":true,"blade":point,"bt":stamp})
func move_to(point: Vector2, ms: int) -> void:
    blade(point,int(clock.get("stamp",1000))+ms)
func hover_to(point: Vector2) -> void:
    for op in Bot.hover(Vector2(clock.get("blade",Vector2(.5,.5))),point): move_to(op.p,int(op.dt))
func pass_time(seconds: float) -> void:
    focus();session._tick_cleans(seconds)
func play(mode: String="perfect") -> void:
    Bot.play_step(func() -> Dictionary: return active(),
        func(point: Vector2, stamp: int) -> void: blade(point,stamp),
        func(seconds: float) -> void: pass_time(seconds),
        clock,mode,true)
func give(id: String) -> void:
    hunter.inventory.items.append(AnimalCatalog.loot(StringName(id)))
func begin() -> Dictionary:
    focus()
    session.request_action("clean_start")
    return active()
func at_machine() -> void:
    hunter.global_position=cleaner.interaction_position()+Vector3.UP*.1
func pieces(state: Dictionary) -> Array:
    return CleaningPattern.pieces(int(state.seed),float(state.difficulty),bool(state.fatty))
## Waits until a piece of `kind` is high in the air, then flicks straight through it.
func slice_kind(kind: int) -> bool:
    for attempt in 600:
        var state: Dictionary=active()
        if state.is_empty(): return false
        var all: Array=pieces(state)
        for index in all.size():
            var piece: Dictionary=all[index]
            if int(piece.kind)!=kind or int(state.done)&(1<<index) or not CleaningPattern.airborne(piece,float(state.time)): continue
            var at: Vector2=CleaningPattern.position(piece,float(state.time))
            if at.y>.7: continue
            dirt_before=int(state.dirt)
            hover_to(at-Vector2(0,.09));move_to(at+Vector2(0,.09),12)
            return true
        pass_time(.05)
    return false

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    check(session.phase=="lobby","camp loaded")
    hunter=session.local_hunter();hunter.set_physics_process(false);session.set_physics_process(false)
    hunter.inventory.backpack_id=&"hoarder";hunter.inventory.items.clear()
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="cleaner": cleaner=stall
    check(cleaner!=null and cleaner.get_node_or_null("Drum")!=null and cleaner.get_node_or_null("Body")!=null,"the camp has a hide cleaner with a drum")
    if cleaner==null: quit(1);return
    var to_fire: Vector3=(Vector3(0,cleaner.global_position.y,-1.8)-cleaner.global_position).normalized()
    check((-cleaner.global_basis.z).dot(to_fire)>.95,"the machine faces the campfire")

    # --- the pure drum schedule --------------------------------------------
    var rabbit: Array=CleaningPattern.pieces(11,0.0,false)
    check(rabbit==CleaningPattern.pieces(11,0.0,false) and rabbit!=CleaningPattern.pieces(12,0.0,false),"the same seed replays the same drum on every peer")
    var hardest: Array=CleaningPattern.pieces(11,1.0,false)
    check(CleaningPattern.junk_count(rabbit)==10 and CleaningPattern.junk_count(hardest)==28,"harder hides carry more junk")
    var kinds: Dictionary={}
    for piece in hardest: kinds[int(piece.kind)]=true
    var easy_kinds: Dictionary={}
    for piece in rabbit: easy_kinds[int(piece.kind)]=true
    check(kinds.has(CleaningPattern.PELT) and kinds.has(CleaningPattern.JUNK_SINEW) and not easy_kinds.has(CleaningPattern.PELT) and not easy_kinds.has(CleaningPattern.JUNK_SINEW),"the hide flops up and sinew appears only on harder animals")
    var fat_share: Array=[0,0]
    for piece in CleaningPattern.pieces(5,.5,true): fat_share[0]+=1 if int(piece.kind)==CleaningPattern.JUNK_FAT else 0
    for piece in CleaningPattern.pieces(5,.5,false): fat_share[1]+=1 if int(piece.kind)==CleaningPattern.JUNK_FAT else 0
    check(fat_share[0]>fat_share[1],"fatty animals throw off more fat")
    var arc: Dictionary=rabbit[0]
    var apex: Vector2=CleaningPattern.position(arc,float(arc.t)+CleaningPattern.flight(arc)*.5)
    check(apex.y<.45 and CleaningPattern.position(arc,float(arc.t)).y>1.0 and CleaningPattern.landed(arc,float(arc.t)+CleaningPattern.flight(arc)+.01),"pieces rise out of the drum and fall back in")
    check(CleaningPattern.final_stars(5,.9)==5 and CleaningPattern.final_stars(5,.7)==4 and CleaningPattern.final_stars(5,.3)==3 and CleaningPattern.final_stars(1,0.0)==1,"cleanliness costs at most two stars and never below one")

    # --- claiming the machine ----------------------------------------------
    hunter.global_position=cleaner.interaction_position()+Vector3(12,0,0)
    give("rabbit_pelt__r5")
    check(begin().is_empty(),"cannot clean away from the machine")
    at_machine();hunter.inventory.items.clear()
    check(begin().is_empty(),"nothing to clean without a raw hide")
    give("rabbit_pelt__s5")
    check(begin().is_empty(),"an already cleaned hide does not go back in")
    hunter.inventory.items.clear();give("rabbit_pelt__r3");give("rabbit_pelt__r5");give("rabbit_pelt")
    var state: Dictionary=begin()
    check(not state.is_empty() and state.item=="rabbit_pelt__r5" and state.raw_stars==5,"the best raw hide goes into the drum first")
    check(hunter.inventory.items.size()==2 and hunter.cleaning,"the hide leaves the bag while it is in the drum")
    focus()
    check(hunter.command.direction==Vector3.ZERO and session.is_busy(1),"the hunter cannot walk away mid-clean")
    var ammo: int=hunter.inventory.ammunition()
    session._shoot(1,hunter.global_position+Vector3.UP,Vector3.FORWARD)
    check(hunter.inventory.ammunition()==ammo,"no shooting while cleaning")
    session.request_action("clean_cancel")
    check(not session.is_cleaning(1) and hunter.inventory.items.size()==3 and not hunter.cleaning,"cancelling gives the very same raw hide back")
    var ids: Array=[]
    for item in hunter.inventory.items: ids.append(String(item.id))
    check(ids.has("rabbit_pelt__r5"),"the returned hide keeps its stars")

    # --- slicing -----------------------------------------------------------
    hunter.inventory.items.clear();give("rabbit_pelt__r5");clock={}
    state=begin()
    pass_time(.5)
    check(active().dirt==0 and active().cleaned==0,"nothing is judged before the first volley")
    check(slice_kind(int(pieces(state)[0].kind)),"junk comes flying out of the drum")
    state=active()
    check(state.cleaned==1 and state.combo>=1 and EVENTS_HAS(String(state.feedback)),"a flick through flying junk cleans it")
    hover_to(Vector2(.5,.2))
    for i in 40: pass_time(.1)
    state=active()
    check(state.dirt>0 and state.feedback in ["missed",""],"junk nobody slices lands back on the hide")
    session.request_action("clean_cancel")
    check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].id==&"rabbit_pelt__r5","a half-done clean still returns the raw hide")

    hunter.inventory.items.clear();give("rabbit_pelt__r5");clock={}
    begin();play()
    state=session.clean_state(1)
    check(not session.is_cleaning(1) and state.feedback=="complete" and float(state.clean)>=.85,"a careful player cleans the rabbit hide")
    check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].id==&"rabbit_pelt__s5" and hunter.inventory.items[0].sell_value==15,"a clean rabbit hide keeps five stars and full price")
    check(String(state.result)=="rabbit_pelt__s5","the session reports what came out of the drum")

    hunter.inventory.items.clear();give("rabbit_pelt__r5");clock={}
    begin();play("lazy")
    state=session.clean_state(1)
    check(int(state.dirt)==int(state.junk) and float(state.clean)==0.0,"letting everything fall leaves the hide filthy")
    check(hunter.inventory.items[0].id==&"rabbit_pelt__s3","a filthy clean costs two stars")

    # Harder hides: stones, the hide itself and tough sinew.
    hunter.inventory.items.clear();give("wolf_pelt__r5");clock={}
    state=begin()
    check(float(state.difficulty)>.5 and int(state.junk)>10,"a wolf hide is a harder drum")
    check(slice_kind(CleaningPattern.STONE),"stones fly with the junk")
    check(int(active().dirt)-dirt_before==CleaningPattern.DIRT_STONE,"slicing a stone chips the knife and costs cleanliness")
    check(slice_kind(CleaningPattern.PELT),"the hide itself flops up")
    check(int(active().dirt)-dirt_before==CleaningPattern.DIRT_PELT,"cutting the hide costs double")
    check(slice_kind(CleaningPattern.JUNK_SINEW),"tough sinew comes out of a wolf")
    state=active()
    check(state.feedback=="chop" and int(state.cracked)!=0,"sinew takes a first chop")
    var cracked: int=int(state.cracked)
    var index: int=0
    while not cracked&(1<<index): index+=1
    var sinew: Dictionary=pieces(state)[index]
    var at: Vector2=CleaningPattern.position(sinew,float(state.time))
    hover_to(at+Vector2(0,.09));move_to(at-Vector2(0,.09),12)
    check(int(active().done)&(1<<index) and active().feedback=="sinew","and comes off on the second")
    session.request_action("clean_cancel")

    for id in ["deer","boar","wolf","bear","frog","turtle","snake","crocodile","ancient_crocodile"]:
        var definition: AnimalDefinition=AnimalCatalog.animal(StringName(id))
        hunter.inventory.items.clear();give(String(definition.loot_id)+"__r5");clock={}
        begin();play()
        state=session.clean_state(1)
        check(float(state.get("clean",0))>=.85 and hunter.inventory.items[0].id==StringName(String(definition.loot_id)+"__s5"),"a careful player cleans a "+id+" hide "+str(state.get("clean",0)))

    # --- interruptions ------------------------------------------------------
    hunter.inventory.items.clear();give("deer_pelt__r4");clock={}
    begin();hunter.global_position+=Vector3(10,0,0);pass_time(.05)
    check(not session.is_cleaning(1) and hunter.inventory.items[0].id==&"deer_pelt__r4","walking off returns the raw hide")
    at_machine();begin();hunter.control_enabled=false;session._tick_cleans(1.0)
    check(not session.is_cleaning(1) and hunter.inventory.items.size()==1,"closing controls stops the machine and returns the hide")
    hunter.control_enabled=true
    begin();session._clear_cleans()
    check(not session.is_cleaning(1) and hunter.inventory.items[0].id==&"deer_pelt__r4","leaving the camp returns the hide")
    check(var_to_bytes(session.clean_state(1)).size()<1000,"the streamed cleaner state fits in one packet")

    # --- the real panel ------------------------------------------------------
    hunter.inventory.items.clear();give("rabbit_pelt__r5");clock={}
    at_machine();scene._begin_clean();scene._update_clean(0)
    var panel=scene.cleaning_panel
    check(panel.is_open() and panel.is_interactive() and session.is_cleaning(1),"the machine opens the cleaning panel")
    var motion:=InputEventMouseMotion.new();motion.relative=Vector2(100,-50)
    var before: Vector2=session.local_blade
    panel._input(motion)
    check(session.local_blade.x>before.x and session.local_blade.y<before.y,"the mouse steers the knife over the drum")
    check(slice_kind(int(pieces(active())[0].kind)),"first piece flies")
    scene._update_clean(0);panel._process(.016)
    check(not panel._popups.is_empty(),"slices pop arcade feedback")
    play()
    scene._update_clean(0);panel._process(.016)
    check(not session.is_cleaning(1) and not hunter.cleaning and panel._root.visible and hunter.inventory.items[0].id==&"rabbit_pelt__s5","the panel shows the cleaned hide")
    panel._process(3.0);scene._update_clean(0)
    check(not panel._root.visible,"the result card goes away on its own")
    give("rabbit_pelt__r2");scene._begin_clean();scene._update_clean(0)
    var cancel:=InputEventKey.new();cancel.physical_keycode=KEY_E;cancel.pressed=true
    panel._input(cancel)
    check(not session.is_cleaning(1) and not panel.is_open(),"E stops the machine")
    check(cleaner.localized_name().contains("1") or cleaner.localized_name().contains("2"),"the machine counts raw hides in the prompt")

    var locale=root.get_node("LocaleSettings")
    for language in ["ro","en"]:
        locale.set_language(language)
        var keys: Array=["CLEAN_TITLE","CLEAN_PROMPT","CLEAN_NOTHING","CLEAN_UNAVAILABLE","CLEAN_PROGRESS","CLEAN_INFO","CLEAN_RATING","CLEAN_RAW_VALUE","CLEAN_TIP","CLEAN_HINT","CLEAN_DONE_TIP","CLEAN_FEEDBACK_CANCELLED","LOOT_RAW"]
        for event in load("res://ui/cleaning/cleaning_panel.gd").EVENTS.keys(): keys.append_array(["CLEAN_POP_"+String(event).to_upper(),"CLEAN_FEEDBACK_"+String(event).to_upper()])
        var missing: Array=[]
        for key in keys:
            if tr(key)==key: missing.append(key)
        check(missing.is_empty(),"cleaner strings localized "+language+" "+str(missing))
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)

func EVENTS_HAS(feedback: String) -> bool:
    return load("res://ui/cleaning/cleaning_panel.gd").EVENTS.has(feedback)
