extends SceneTree
## Exercise the real host API and inventory. Slashes, scrapes and yanks are
## driven by injecting genuine blade samples through _accept_input and clicks
## through the action path, so every check goes through the live host code.
const Bot=preload("res://tests/harvest_bot.gd")
var scene
var session
var hunter
var checks: int=0
var failures: int=0
var sequence: int=50000
var clocks: Dictionary={1:{},2:{}}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func active_state(peer: int) -> Dictionary:
    var state: Dictionary=session.harvest_state(peer)
    return state if bool(state.get('active',false)) else {}
func focus(peer: int=1) -> void:
    sequence+=1
    session._accept_input(peer,{"seq":sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"harvest":true})
## One blade sample through the real input path. `stamp` is the sender's own
## clock in milliseconds, which is what the host measures blade speed against.
func blade(point: Vector2, stamp: int, peer: int=1) -> void:
    sequence+=1
    var clock: Dictionary=clocks[peer]
    clock.stamp=stamp;clock.blade=point
    session._accept_input(peer,{"seq":sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"harvest":true,"blade":point,"bt":stamp})
## A sample `ms` after the previous one on this peer's clock.
func move_to(point: Vector2, ms: int, peer: int=1) -> void:
    blade(point,int(clocks[peer].get("stamp",1000))+ms,peer)
func hover_to(point: Vector2, peer: int=1) -> void:
    for op in Bot.hover(Vector2(clocks[peer].get("blade",Vector2(.5,.5))),point): move_to(op.p,int(op.dt),peer)
func click(point: Vector2, peer: int=1) -> void:
    var state: Dictionary=active_state(peer)
    if state.is_empty(): return
    var clock: Dictionary=clocks[peer]
    clock.click=maxi(int(clock.get("click",0)),int(state.clicks))+1
    session._action(peer,"harvest_click","%d:%d:%d:%.5f:%.5f" % [state.id,state.token,clock.click,point.x,point.y])
func pass_time(seconds: float, peer: int=1) -> void:
    focus(peer);session._tick_harvests(seconds)
## One unit of work, whichever move the job is currently in.
func step(peer: int=1, mode: String="perfect") -> Dictionary:
    Bot.play_step(func() -> Dictionary: return active_state(peer),
        func(point: Vector2, stamp: int) -> void: blade(point,stamp,peer),
        func(value: String) -> void: session._action(peer,"harvest_click",value),
        func(seconds: float) -> void: pass_time(seconds,peer),
        clocks[peer],mode)
    return active_state(peer)
func finish(peer: int=1, mode: String="perfect") -> void:
    for i in 40:
        var state: Dictionary=active_state(peer)
        if state.is_empty(): return
        step(peer,mode)
        var now: Dictionary=active_state(peer)
        if not now.is_empty() and int(now.completed)==int(state.completed): return
func until_move(move: int, peer: int=1) -> Dictionary:
    for i in 20:
        var state: Dictionary=active_state(peer)
        if state.is_empty() or int(state.move)==move: return state
        step(peer)
    return active_state(peer)
## Rest pose and live ends of seam `index` in the current wave.
func seam(state: Dictionary, index: int=0) -> Dictionary:
    var q: PackedStringArray=PackedStringArray(state.quirks)
    var length: float=float(state.seam_length)
    var jaw: int=HarvestPattern.jaw_side(int(state.id)) if q.has("chomp") else 0
    var rest: Dictionary=HarvestPattern.seams(int(state.id),int(state.step),int(state.seams),length,jaw)[index]
    var ends: Array=HarvestPattern.seam_ends(rest,length,HarvestPattern.drift(q,int(state.id),float(state.move_time),rest.c))
    var centre: Vector2=(Vector2(ends[0])+Vector2(ends[1]))*.5
    var normal: Vector2=HarvestPattern.seam_normal(rest)
    return {"rest":rest,"ends":ends,"centre":centre,"normal":normal}
func norm(point: Vector2) -> Vector2: return Vector2(point.x/HarvestPattern.ASPECT,point.y)
## A straight pass over seam `index`, from one side to the other, taking `ms`.
func flick(state: Dictionary, index: int=0, ms: int=12, reverse: bool=false, peer: int=1) -> void:
    var geometry: Dictionary=seam(state,index)
    var side: Vector2=geometry.normal*(-1.0 if reverse else 1.0)
    hover_to(norm(geometry.centre-side*.07),peer)
    move_to(norm(geometry.centre+side*.07),ms,peer)
func body(kind: StringName):
    var animal=session.spawn_animal(kind,Vector3(20,0,-50))
    animal.set_physics_process(false)
    animal.global_position=Vector3(20,30,-50)
    animal.take_damage(99999,hunter.global_position,1)
    hunter.global_position=animal.global_position+Vector3(1.6,0,0)
    return animal
func begin(animal) -> Dictionary:
    focus()
    session.request_action("harvest_start",str(animal.animal_id))
    return active_state(1)
func fill_bag() -> void:
    hunter.inventory.items.clear()
    for i in hunter.inventory.capacity(): hunter.inventory.collect(AnimalCatalog.loot(&"rabbit_pelt"))

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    check(session.phase=="hunt","real hunt loaded for manual harvesting")
    session.set_physics_process(false);hunter=session.local_hunter();hunter.set_physics_process(false)
    hunter.inventory.backpack_id=&"hoarder"
    for animal in session.animals.values(): animal.set_physics_process(false)

    # --- the shared skinning geometry -------------------------------------
    check(HarvestPattern.total_steps(2)==3 and HarvestPattern.total_steps(14)==14,"workload has at least three steps")
    var split: Array=HarvestPattern.plan(10,PackedStringArray(["fat"]))
    check(int(split[0])+int(split[1])+int(split[2])==10 and int(split[1])==2 and int(split[2])==2,"fatty bodies trade slashes for scrapes")
    check(HarvestPattern.plan(2)==[2,0,1],"a rabbit is two slash waves and one yank")
    check(HarvestPattern.move_of(0,10,PackedStringArray(["fat"]))==HarvestPattern.MOVE_SLASH and HarvestPattern.move_of(6,10,PackedStringArray(["fat"]))==HarvestPattern.MOVE_SCRAPE and HarvestPattern.move_of(9,10,PackedStringArray(["fat"]))==HarvestPattern.MOVE_YANK,"moves run slash, scrape, yank")
    var seams_a: Array=HarvestPattern.seams(7,0,4,.3)
    check(seams_a.size()==4 and seams_a==HarvestPattern.seams(7,0,4,.3),"same seed rebuilds identical seams on every peer")
    check(HarvestPattern.seams(8,0,4,.3)!=seams_a and HarvestPattern.seams(7,1,4,.3)!=seams_a,"different body or step yields different seams")
    var ends: Array=HarvestPattern.seam_ends(seams_a[0],.3,Vector2.ZERO)
    var middle: Vector2=(Vector2(ends[0])+Vector2(ends[1]))*.5
    var across: Vector2=HarvestPattern.seam_normal(seams_a[0])
    var hit: Array=HarvestPattern.crossing(middle-across*.1,middle+across*.1,ends)
    check(hit.size()==1 and absf(float(hit[0]))<.01,"a flick through the middle crosses the seam at its centre")
    check(HarvestPattern.crossing(middle+across*.05,middle+across*.2,ends).is_empty(),"a flick beside the seam misses it")
    var moods: Dictionary={}
    for i in 80: moods[HarvestPattern.spasm(3,float(i)*.05,3.0)]=true;moods[10+HarvestPattern.jaw_state(3,float(i)*.05,3.0)]=true
    check(moods.size()==6,"spasms and jaws cycle through calm, warning and strike")

    var corpse=body(&"rabbit")
    check(corpse.dead and session.loot.is_empty() and hunter.inventory.items.is_empty(),"death produces no automatic pelt or reward")
    corpse._physics_process(8.0)
    check(session.animals.has(corpse.animal_id),"corpse persists beyond the old four-second disappearance")
    hunter.global_position+=Vector3(20,0,0)
    check(begin(corpse).is_empty(),"cannot harvest from far away")
    hunter.global_position=corpse.global_position+Vector3(1.6,0,0)
    hunter.health=0
    check(begin(corpse).is_empty(),"downed hunter cannot harvest")
    hunter.health=100;hunter.seat_index=1
    check(begin(corpse).is_empty(),"seated hunter cannot harvest")
    hunter.seat_index=-1
    var alive=session.spawn_animal(&"rabbit",Vector3(20,0,-50));alive.set_physics_process(false);alive.global_position=corpse.global_position
    check(begin(alive).is_empty(),"living animal cannot be harvested")
    session.remove_animal(alive.animal_id)
    await frames(2)
    var state=begin(corpse)
    check(not state.is_empty() and state.required==3 and state.move==HarvestPattern.MOVE_SLASH and state.hp.size()==2,"rabbit opens on a two-seam slash wave")
    if state.is_empty(): quit(1);return
    pass_time(10.0)
    check(active_state(1).completed==0 and hunter.inventory.items.is_empty() and active_state(1).wear==0,"waiting alone never cuts or damages")
    var ammo: int=hunter.inventory.ammunition()
    session._shoot(1,hunter.global_position+Vector3.UP,Vector3.FORWARD)
    check(hunter.inventory.ammunition()==ammo,"host prevents firing while skinning")
    state=active_state(1)
    flick(state,0,600)
    check(active_state(1).hp[0]==1 and active_state(1).wear==0,"a hovering knife glides over a seam without cutting")
    flick(active_state(1),0,220)
    check(active_state(1).hp[0]==1 and active_state(1).wear==10 and active_state(1).feedback=="snag","a lazy pass snags the hide instead of cutting")
    click(norm(seam(active_state(1)).centre))
    check(active_state(1).hp[0]==1 and active_state(1).wear==10,"clicking does nothing during slashes")
    var clicks_before: int=int(active_state(1).clicks)
    var parked: Vector2=Vector2(clocks[1].blade)
    click(Vector2(-.1 if parked.x>.5 else 1.1,-.1 if parked.y>.5 else 1.1))
    check(int(active_state(1).clicks)==clicks_before,"a click far from the blade is rejected as a teleport")
    flick(active_state(1),0)
    state=active_state(1)
    check(state.hp[0]==0 and state.wear==10 and state.feedback=="perfect","a fast flick through the centre is a perfect cut")
    check(state.combo==1 and int(state.fx)>0,"a cut starts the combo and publishes a visual event")
    flick(state,1)
    state=active_state(1)
    check(state.completed==1 and state.move==HarvestPattern.MOVE_SLASH and state.hp==[1,1],"clearing every seam completes the wave and lays out a fresh one")
    session.request_action("harvest_cancel")
    check(not session.is_harvesting(1) and corpse.harvest_completed==1,"cancel releases body and preserves work")
    state=begin(corpse)
    check(state.completed==1 and state.wear==10,"resuming continues completed work and keeps its damage")
    session.request_action("harvest_cancel")

    hunter.inventory.items.clear();corpse=body(&"rabbit");state=begin(corpse)
    finish()
    check(corpse.harvested and hunter.inventory.items.size()==1,"last yank awards one recovered pelt")
    check(hunter.inventory.items[0].stars==5 and hunter.inventory.items[0].sell_value==15,"flawless skinning produces pristine value")
    check(begin(corpse).is_empty() and hunter.inventory.items.size()==1,"harvested corpse cannot pay twice")

    # Every species runs the same host path, gets strictly harder, and has its twist.
    var expected: Dictionary={&"rabbit":[],&"deer":["ticks"],&"boar":["thick","fat"],&"wolf":["twitch"],&"bear":["bees","fat"],
        &"frog":["slippery"],&"turtle":["shell"],&"snake":["wiggle"],&"crocodile":["chomp","thick"],&"ancient_crocodile":["chomp","thick","twitch"]}
    for biome in [AnimalCatalog.ANIMALS,AnimalCatalog.SWAMP_ANIMALS]:
        var previous_steps: int=0
        var previous_length: float=INF
        var previous_speed: float=0.0
        var previous_sweet: float=INF
        for definition in biome:
            hunter.inventory.items.clear()
            var animal=body(definition.id)
            state=begin(animal)
            check(not state.is_empty(),"manual harvest available "+str(definition.id))
            if state.is_empty(): continue
            check(Array(state.quirks)==Array(expected[definition.id]),"species twist "+str(definition.id))
            check(var_to_bytes(state).size()<1000,"streamed slash state stays small "+str(definition.id))
            var tuning: Dictionary=definition.harvest_tuning(0,int(state.required))
            check(state.required>previous_steps and float(state.seam_length)<previous_length and float(state.min_speed)>=previous_speed and float(tuning.sweet_width)<previous_sweet,"difficulty rises within biome "+str(definition.id))
            previous_steps=state.required;previous_length=float(state.seam_length);previous_speed=float(state.min_speed);previous_sweet=float(tuning.sweet_width)
            var seen: Dictionary={}
            for i in 40:
                var now: Dictionary=active_state(1)
                if now.is_empty(): break
                seen[int(now.move)]=true
                step()
            check(seen.has(HarvestPattern.MOVE_SLASH) and seen.has(HarvestPattern.MOVE_YANK) and seen.has(HarvestPattern.MOVE_SCRAPE)==definition.harvest_quirks.has("fat"),"routine plays its moves "+str(definition.id))
            check(animal.harvested and hunter.inventory.items.size()==1 and hunter.inventory.items[0].base_id==definition.loot_id,"correct species material recovered "+str(definition.id))
            check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].stars==5,"a careful player keeps five stars on "+str(definition.id))
            session.remove_animal(animal.animal_id)

    # --- each twist actually bites ----------------------------------------
    hunter.inventory.items.clear();corpse=body(&"deer");state=begin(corpse)
    var bugs: PackedVector2Array=PackedVector2Array()
    for i in 80:
        # Wait until the tick has crawled clear of every seam, so only it is hit.
        state=active_state(1)
        bugs=HarvestPattern.ticks(int(state.id),int(state.step),float(state.move_time),int(state.hazards))
        var clear: bool=true
        for index in state.hp.size():
            var geometry: Dictionary=seam(state,index)
            if not HarvestPattern.crossing(HarvestPattern.metric(bugs[0])-Vector2(.06,0),HarvestPattern.metric(bugs[0])+Vector2(.06,0),geometry.ends).is_empty(): clear=false
        if clear: break
        pass_time(.1)
    hover_to(bugs[0]-Vector2(.06/HarvestPattern.ASPECT,0));move_to(bugs[0]+Vector2(.06/HarvestPattern.ASPECT,0),12)
    state=active_state(1)
    check(state.feedback=="splat" and state.wear==35 and int(state.dead)&1,"slicing through a tick bursts it and stains the hide")
    session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)

    corpse=body(&"wolf");state=begin(corpse)
    check(bool(state.directional),"wolves demand cuts in the arrow's direction")
    for i in 80:
        if not Bot.unsafe(active_state(1)): break
        pass_time(.05)
    flick(active_state(1),0,12,true)
    check(active_state(1).feedback=="wrong_way" and active_state(1).wear==20 and active_state(1).hp[0]==1,"cutting against the arrow tears instead of cutting")
    for i in 80:
        if HarvestPattern.spasm(int(state.id),float(active_state(1).move_time),float(state.twitch_period))==2: break
        pass_time(.05)
    flick(active_state(1),0)
    check(active_state(1).feedback=="spasm" and active_state(1).hp[0]==1 and active_state(1).wear==60,"cutting while the corpse kicks skids the knife")
    session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)

    corpse=body(&"crocodile");state=begin(corpse)
    var jaw: int=HarvestPattern.jaw_side(int(state.id))
    hover_to(Vector2(.08 if jaw<0 else .92,.5))
    for i in 120:
        pass_time(.05)
        if active_state(1).feedback=="chomp": break
    check(active_state(1).feedback=="chomp" and active_state(1).wear==70,"resting the knife in the jaw zone gets it bitten")
    pass_time(.2)
    check(active_state(1).wear==70,"one snap bites only once")
    check(HarvestPattern.in_jaw(norm(seam(active_state(1),0).centre),jaw),"the first seam always sits inside the bite zone")
    hover_to(Vector2(.5,.5))
    state=active_state(1)
    for i in 80:
        if not Bot.unsafe(active_state(1)): break
        pass_time(.05)
    flick(active_state(1),0)
    check(active_state(1).feedback=="crack" and active_state(1).hp[0]==1,"armoured seams crack on the first cut")
    flick(active_state(1),0)
    check(active_state(1).hp[0]==0,"and open on the second")
    session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)

    for kind in [&"frog",&"snake"]:
        corpse=body(kind);state=begin(corpse)
        var before: Vector2=seam(state).centre
        pass_time(.6)
        check(seam(active_state(1)).centre.distance_to(before)>.01,"seams move on a "+str(kind))
        step()
        check(active_state(1).completed==1 and active_state(1).wear==0,"moving seams can still be cut cleanly on a "+str(kind))
        session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)

    corpse=body(&"bear");state=begin(corpse)
    state=until_move(HarvestPattern.MOVE_SCRAPE)
    check(state.move==HarvestPattern.MOVE_SCRAPE and state.fat.size()>=4,"the bear needs its fat scraped")
    var worn: int=int(state.wear)
    var scrape_step: int=int(state.completed)
    var blobs: PackedVector2Array=HarvestPattern.fat(int(state.id),int(state.step),int(state.fat_count),float(state.fat_radius))
    var fat_bees: PackedVector2Array=HarvestPattern.bees(int(state.id),int(state.step),float(state.move_time),int(state.hazards))
    hover_to(blobs[0])
    for i in 2: move_to(blobs[0]+Vector2(.03 if i%2==0 else -.03,0),20)
    check(float(active_state(1).fat[0])<1.0,"scrubbing wears a fat blob down")
    pass_time(float(state.scrape_time)+.1)
    state=active_state(1)
    check(state.wear>worn and state.completed==scrape_step+1,"setting fat damages the hide and the routine moves on")
    check(fat_bees.size()>=3,"bears bring a small swarm")
    session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)

    # --- the yank ----------------------------------------------------------
    corpse=body(&"rabbit");state=until_move(HarvestPattern.MOVE_YANK) if not begin(corpse).is_empty() else {}
    check(not state.is_empty() and state.move==HarvestPattern.MOVE_YANK and not state.grabbed,"rabbit ends with the yank")
    var flap: Dictionary=HarvestPattern.yank(int(state.id),int(state.step))
    hover_to(flap.ring+Vector2(.12,.12));click(flap.ring+Vector2(.12,.12))
    check(not active_state(1).grabbed and active_state(1).feedback=="fumble","clicking beside the ring fumbles")
    hover_to(flap.ring);click(flap.ring)
    check(active_state(1).grabbed and active_state(1).feedback=="grab","clicking the ring grabs the flap")
    worn=int(active_state(1).wear)
    click(flap.ring)
    check(not active_state(1).grabbed and active_state(1).feedback=="boing" and active_state(1).wear==worn+15,"releasing without tension snaps the flap back: BOING")
    hover_to(flap.ring);click(flap.ring)
    hover_to(HarvestPattern.yank_point(flap.ring,flap.dir,HarvestPattern.YANK_RIP+.1))
    check(not session.is_harvesting(1) and corpse.harvested and corpse.harvest_wear>=worn+15+110,"overstretching rips the hide off in tatters")

    # Sloppy work is what actually costs stars.
    hunter.inventory.items.clear();corpse=body(&"rabbit");state=begin(corpse)
    step(1,"sloppy")
    check(corpse.harvest_wear>0 and corpse.harvest_completed==1,"cutting near the seam ends damages the hide")
    var wandered: int=corpse.harvest_wear
    session.request_action("harvest_cancel");state=begin(corpse)
    check(state.wear==wandered,"cancel cannot repair a damaged hide")
    finish(1,"sloppy")
    check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].stars<5,"sloppy work costs stars")
    hunter.inventory.items.clear();corpse=body(&"rabbit");begin(corpse)
    finish(1,"ruin")
    check(corpse.harvest_wear>680,"snagging and ripping ruins the hide outright")
    check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].stars==1 and hunter.inventory.items[0].sell_value==1,"butchered skin gives one star and ten percent value")
    var item=hunter.inventory.items[0]
    var save: Dictionary=hunter.inventory.export_state()
    hunter.inventory.items.clear();hunter.inventory.apply_state(save)
    check(hunter.inventory.items[0].id==item.id and hunter.inventory.loot_value()==1,"quality survives inventory serialization")
    hunter.global_position=session.jeep.to_global(Vector3(0,.2,2.55));session.request_action("deposit")
    check(session.trunk.size()==1 and session.trunk[0].kind==String(item.id) and session.trunk[0].owner==session.identities[1],"cargo preserves quality and stable owner")
    session.request_action("withdraw")
    check(session.trunk.is_empty() and hunter.inventory.loot_value()==1,"withdrawal preserves skin quality value")
    check(AnimalCatalog.loot(&"rabbit_pelt__q0")==null and AnimalCatalog.loot(&"rabbit_pelt__q9")==null and AnimalCatalog.loot(&"unknown__q1")==null,"unknown quality and loot IDs rejected")

    # The wear-to-star ladder, end to end through minting, naming and sale.
    check(AnimalCatalog.stars_from_wear(0)==5 and AnimalCatalog.stars_from_wear(60)==5 and AnimalCatalog.stars_from_wear(61)==4,"five-star band ends exactly at sixty wear")
    check(AnimalCatalog.stars_from_wear(220)==4 and AnimalCatalog.stars_from_wear(430)==3 and AnimalCatalog.stars_from_wear(680)==2 and AnimalCatalog.stars_from_wear(681)==1 and AnimalCatalog.stars_from_wear(5000)==1,"wear bands map onto every star tier")
    for sample in [{"wear":0,"stars":5,"percent":150},{"wear":150,"stars":4,"percent":120},{"wear":300,"stars":3,"percent":100},{"wear":500,"stars":2,"percent":50},{"wear":900,"stars":1,"percent":10}]:
        hunter.inventory.items.clear();corpse=body(&"deer");state=begin(corpse)
        corpse.harvest_wear=int(sample.wear)
        check(int(active_state(1).stars)==int(sample.stars),"live preview rates wear "+str(sample.wear))
        finish()
        var recovered: LootDefinition=hunter.inventory.items[0]
        var base: LootDefinition=AnimalCatalog.loot(&"deer_pelt")
        check(recovered.stars==sample.stars and recovered.id==StringName("deer_pelt__s%d" % sample.stars),"host awards star tier "+str(sample.stars))
        check(recovered.sell_value==roundi(base.sell_value*float(sample.percent)/100),"star tier price "+str(sample.stars))
        var wallet_before: int=hunter.inventory.coins
        var earned: int=hunter.inventory.sell_all()
        check(earned==recovered.sell_value and hunter.inventory.coins==wallet_before+earned,"sale pays actual starred value "+str(sample.stars))
    for legacy in [{"q":1,"value":12},{"q":2,"value":10},{"q":3,"value":7}]:
        var old: LootDefinition=AnimalCatalog.loot(StringName("rabbit_pelt__q%d" % legacy.q))
        check(old.quality==legacy.q and old.stars==0 and old.sell_value==legacy.value,"legacy quality keeps its value "+str(legacy.q))
    check(AnimalCatalog.loot(&"rabbit_pelt__s0")==null and AnimalCatalog.loot(&"rabbit_pelt__s6")==null and AnimalCatalog.loot(&"rabbit_pelt__s05")==null and AnimalCatalog.loot(&"unknown__s5")==null,"malformed star IDs cannot forge loot")

    hunter.inventory.items.clear();corpse=body(&"ancient_crocodile");state=begin(corpse)
    var initial_length: float=float(state.seam_length)
    var initial_sweet: float=float(corpse.definition.harvest_tuning(0,14).sweet_width)
    for i in int(state.required)-1: step()
    state=active_state(1)
    check(state.required==14 and state.move==HarvestPattern.MOVE_YANK and is_equal_approx(state.pressure,1.0),"fourteen-step ancient hide ramps to its hardest finish")
    check(float(state.sweet_width)<initial_sweet,"the final yank has the narrowest green zone")
    check(var_to_bytes(state).size()<1000,"the streamed harvest state fits comfortably in one packet")
    var final_sweet: float=float(state.sweet_width)
    session.request_action("harvest_cancel");state=begin(corpse)
    check(is_equal_approx(float(state.sweet_width),final_sweet),"resuming cannot reset finishing difficulty")
    check(float(corpse.definition.harvest_tuning(13,14).seam_length)<=initial_length,"seams never grow back over the course of a body")
    finish()
    check(corpse.harvested and hunter.inventory.items.size()==1 and hunter.inventory.items[0].stars==5,"even the ancient crocodile can be skinned perfectly")
    hunter.inventory.items.clear();corpse=body(&"rabbit");state=until_move(HarvestPattern.MOVE_YANK) if not begin(corpse).is_empty() else {}
    flap=HarvestPattern.yank(int(state.id),int(state.step))
    hover_to(flap.ring)
    session._action(1,"harvest_click","%d:%d:%d:%.5f:%.5f" % [state.id,int(state.token)+1,99,flap.ring.x,flap.ring.y])
    check(not active_state(1).grabbed and active_state(1).wear==0,"wrong job token cannot grab or damage skin")
    session.request_action("harvest_cancel");session.remove_animal(corpse.animal_id)
    hunter.inventory.items.clear();corpse=body(&"rabbit");state=begin(corpse)
    step();fill_bag();finish()
    check(not corpse.harvested and not session.is_harvesting(1),"bag filling during work cannot consume the corpse")
    hunter.inventory.items.clear();state=begin(corpse)
    if session.is_harvesting(1): finish()
    check(hunter.inventory.items.size()==1 and not session.animals.has(corpse.animal_id),"completed work remains recoverable after making bag room")

    corpse=body(&"deer");fill_bag()
    check(begin(corpse).is_empty() and not corpse.harvested,"full bag prevents claiming a corpse")
    hunter.inventory.items.clear();state=begin(corpse);step()
    hunter.take_damage(1);focus();session._tick_harvests(.01)
    check(not session.is_harvesting(1) and corpse.harvest_completed==1,"taking damage interrupts and preserves completed steps")
    state=begin(corpse);hunter.global_position+=Vector3(12,0,0);focus();session._tick_harvests(.01)
    check(not session.is_harvesting(1) and corpse.harvest_owner==0,"leaving range releases the corpse")
    hunter.global_position=corpse.global_position+Vector3(1.6,0,0);state=begin(corpse)
    hunter.control_enabled=false;session._tick_harvests(1.0)
    check(not session.is_harvesting(1),"closing local controls releases harvest lock")
    hunter.control_enabled=true
    state=begin(corpse)
    var other=session._spawn_player(2,"Other");other.set_physics_process(false);other.world_ready=true;other.global_position=hunter.global_position
    session.identities[2]="12345678901234567890123456789012"
    focus(2);session._action(2,"harvest_start",str(corpse.animal_id))
    check(not session.is_harvesting(2) and corpse.harvest_owner==1,"second hunter cannot claim occupied corpse")
    session.request_action("harvest_cancel");focus(2);session._action(2,"harvest_start",str(corpse.animal_id))
    check(session.is_harvesting(2) and active_state(2).completed==1,"teammate can continue after explicit release")
    step(2)
    check(active_state(2).completed==2,"teammate's own blade samples are judged on their own job")
    other.command["time"]=Time.get_ticks_msec()-1000;session._tick_harvests(1.0)
    check(not session.is_harvesting(2) and corpse.harvest_owner==0,"stale remote input releases harvest lock")
    state=begin(corpse)
    var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.25,3,3)
    shape.shape=box;wall.add_child(shape);wall.position=corpse.global_position+Vector3(.8,1,0);scene.add_child(wall)
    await frames(3);focus();session._tick_harvests(.01)
    check(not session.is_harvesting(1),"solid obstacle interrupts harvesting")
    check(begin(corpse).is_empty(),"cannot start harvesting through a wall")
    wall.queue_free();await frames(3)
    state=begin(corpse);session.phase="loading";focus();session._tick_harvests(.01)
    check(not session.is_harvesting(1) and corpse.harvest_owner==0,"loading cancels all harvest claims")
    session.phase="hunt"
    state=begin(corpse);session.world_epoch+=1;focus();session._tick_harvests(.01)
    check(not session.is_harvesting(1),"new world epoch rejects old harvest job")
    session.world_epoch-=1
    state=begin(corpse);corpse._physics_process(601)
    check(session.animals.has(corpse.animal_id),"active harvest protects corpse from idle expiry")
    session.request_action("harvest_cancel");var expired_id: int=corpse.animal_id;corpse._physics_process(601)
    check(not session.animals.has(expired_id),"unclaimed corpse eventually expires")
    hunter.inventory.items.clear();corpse=body(&"rabbit");state=begin(corpse)
    var claimed_id: int=corpse.animal_id
    for i in 83:
        var excess=session.spawn_animal(&"rabbit",Vector3(20,0,-50));excess.set_physics_process(false)
        excess.global_position=Vector3(20,30,-50);excess.take_damage(99999,hunter.global_position,1)
    var corpse_count: int=0
    for animal in session.animals.values():
        if animal.dead: corpse_count+=1
    check(corpse_count<=session.MAX_CORPSES and session.animals.has(claimed_id),"corpse budget bounds entities and protects occupied body")
    session.request_action("harvest_cancel")
    var live_before: int=0
    for animal in session.animals.values():
        if not animal.dead: live_before+=1
    session._spawn_near_player()
    var live_after: int=0
    for animal in session.animals.values():
        if not animal.dead: live_after+=1
    check(live_after==live_before+1,"dead bodies do not prevent wildlife replenishment")

    # --- the real panel and the real knife --------------------------------
    hunter.inventory.items.clear();corpse=body(&"rabbit")
    scene._begin_harvest(corpse);scene._update_harvest(0)
    var panel=scene.harvest_panel
    check(panel.is_open() and not panel.pending and panel.is_interactive(),"E interaction opens the actual skinning panel")
    check(scene._harvest_tool.visible and scene._harvest_tool.find_children("*","MeshInstance3D",true,false).size()>1,"manual harvest presents knife and hand")
    var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
    panel._input(press)
    check(active_state(1).completed==0 and active_state(1).wear==0,"a click during slashes is harmless")
    var before_blade: Vector2=session.local_blade
    var motion:=InputEventMouseMotion.new();motion.relative=Vector2(120,40)
    panel._input(motion)
    check(session.local_blade.x>before_blade.x and session.local_blade.y>before_blade.y,"mouse motion steers the virtual knife")
    var knife_rest: Vector3=scene._harvest_tool._knife_hand.position
    scene._harvest_tool._process(.2)
    check(scene._harvest_tool._knife_hand.position.distance_to(knife_rest)>.01,"the knife follows the player's blade onto the hide")
    clocks[1]={}
    step()
    scene._update_harvest(0);scene._harvest_tool._process(.1);panel._process(.016)
    check(active_state(1).completed==1,"a slash wave completes through the real host")
    check(float(scene._harvest_tool._fur.get_shader_parameter("peel"))>0,"finished work peels the hide open in 3D")
    check(scene._harvest_tool._debris.size()>0,"cutting throws debris off the blade")
    check(not panel._popups.is_empty(),"cuts pop arcade feedback on the panel")
    step()
    state=active_state(1);scene._update_harvest(0)
    check(int(state.move)==HarvestPattern.MOVE_YANK,"after the slashes the job reaches the yank")
    flap=HarvestPattern.yank(int(state.id),int(state.step))
    hover_to(flap.ring);session.local_blade=flap.ring
    panel._input(press);scene._update_harvest(0)
    check(active_state(1).grabbed,"a real click through the panel grabs the flap")
    var target: Vector2=HarvestPattern.yank_point(flap.ring,flap.dir,HarvestPattern.YANK_SWEET-HarvestPattern.yank_wobble(int(state.id),float(active_state(1).move_time),float(state.wobble)))
    hover_to(target);session.local_blade=target
    scene._update_harvest(0);scene._harvest_tool._process(.1)
    check(scene._harvest_tool._support_hand.position.distance_to(scene._harvest_tool._knife_hand.position)<.2,"the free hand drags the flap with the pull")
    panel._input(press);scene._update_harvest(0)
    check(not session.is_harvesting(1) and hunter.inventory.items.size()==1 and hunter.inventory.items[0].stars==5,"releasing in the green rips the pelt off through the actual UI")
    var tool_fx: String=scene._harvest_tool._last_stroke
    scene._harvest_tool.observe(session.harvest_state(1))
    check(scene._harvest_tool._last_stroke==tool_fx,"repeated snapshot cannot repeat knife animation")
    check(hunter.harvest_input_guard,"final click guards against firing or jumping with same press")
    check(scene._harvest_tool.visible and scene._harvest_tool.is_finishing(),"last yank keeps the finishing peel animation visible")
    scene._harvest_tool._process(1.0);scene._update_harvest(0)
    check(not scene._harvest_tool.visible and hunter.harvest_target==0,"finishing animation releases camera and controls exactly once")
    panel._process(1.3);scene._update_harvest(0)
    check(not panel._root.visible,"expired completion panel stays hidden on repeated state")
    hunter.inventory.items.clear();corpse=body(&"rabbit")
    scene._begin_harvest(corpse);scene._update_harvest(0)
    var cancel:=InputEventKey.new();cancel.physical_keycode=KEY_E;cancel.pressed=true
    panel._input(cancel)
    check(not session.is_harvesting(1) and not panel.is_open() and corpse.harvest_owner==0,"E cancels actual panel and releases corpse")
    var settings=root.get_node("LocaleSettings")
    settings.set_perspective("first")
    hunter.camera_rig.view_model._process(.016)
    check(hunter.camera_rig.view_model.visible,"first-person weapon visible before manual harvest")
    scene._begin_harvest(corpse);scene._update_harvest(0)
    hunter.camera_rig.view_model._process(.016)
    check(not hunter.camera_rig.view_model.visible,"first-person child cannot redraw gun during knife recovery")
    scene._cancel_harvest();hunter.camera_rig.view_model._process(.016)
    check(not scene._harvest_tool.visible and hunter.camera_rig.view_model.visible,"cancel restores first-person weapon and hides recovery tool")
    settings.set_perspective("third")
    var locale=root.get_node("LocaleSettings")
    for language in ["ro","en"]:
        locale.set_language(language)
        for quality in [1,2,3]:
            var material=AnimalCatalog.loot(StringName("rabbit_pelt__q%d" % quality))
            check(not material.localized_name().contains("HARVEST_QUALITY"),"quality label localized "+language+str(quality))
        for stars in range(1,6):
            var material=AnimalCatalog.loot(StringName("rabbit_pelt__s%d" % stars))
            check(material.localized_name().contains("★") and not material.localized_name().contains("HARVEST_STARS"),"star name localized "+language+str(stars))
        var keys: Array=["HARVEST_COMBO","HARVEST_LEVEL","HARVEST_HINT_SLASH","HARVEST_HINT_SLASH_DIR","HARVEST_HINT_SCRAPE","HARVEST_HINT_GRAB","HARVEST_HINT_PULL","HARVEST_HINT_JAW","HARVEST_HINT_SPASM","HARVEST_TIP"]
        for move in 3: keys.append_array(["HARVEST_MOVE_%d" % move,"HARVEST_TIP_%d" % move])
        for quirk in ["ticks","shell","thick","fat","wiggle","twitch","bees","chomp","slippery"]: keys.append("HARVEST_QUIRK_"+quirk.to_upper())
        for event in load("res://ui/harvest/harvest_panel.gd").EVENTS.keys(): keys.append_array(["HARVEST_POP_"+String(event).to_upper(),"HARVEST_FEEDBACK_"+String(event).to_upper()])
        var missing: Array=[]
        for key in keys:
            if tr(key)==key: missing.append(key)
        check(missing.is_empty(),"skinning strings localized "+language+" "+str(missing))
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
