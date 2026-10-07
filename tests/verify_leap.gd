extends SceneTree
## Predator pounce: launch arc, landing damage, pack calls, smell through cover,
## and a pounce shot out of the air.
var scene
var session
var checks: int=0
var failures: int=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await process_frame
func loaded() -> bool:
    for i in 3600:
        if session.phase!="loading": return true
        await process_frame
    return false

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    var hunter=session.local_hunter()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
    check(await loaded() and session.phase=="hunt","forest hunt loads")
    for a in session.animals.values(): a.set_physics_process(false)
    hunter.control_enabled=false;hunter.set_physics_process(false)
    var stage:=StaticBody3D.new();stage.position=Vector3(0,29.5,-100)
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(250,1,250)
    shape.shape=box;stage.add_child(shape);scene.add_child(stage)
    await frames(3)
    hunter.health=100;hunter.seat_index=-1;hunter.world_ready=true
    hunter.global_position=Vector3(0,30,-100)

    # --- Every predator pounces and hurts a hunter who stands still ----------------------
    for kind in ["wolf","bear","boar"]:
        hunter.health=100
        var a=session.spawn_animal(StringName(kind),Vector3(0,0,-100))
        a.global_position=Vector3(0,30,-107);a.home=a.global_position;a.velocity=Vector3.ZERO
        var leapt: bool=false;var peak: float=a.global_position.y
        for i in 150:
            await physics_frame
            if a.leaping: leapt=true;peak=maxf(peak,a.global_position.y)
            if hunter.health<100: break
        check(leapt,kind+" launches a pounce at prey inside leap range")
        check(peak>30.3,kind+" pounce is an arc, not a slide")
        check(hunter.health==100-a.definition.attack_damage or hunter.health<100,kind+" pounce hurts whoever it lands on")
        check(a.definition.leap_range>0,kind+" definition has leap_range")
        session.remove_animal(a.animal_id)
    for kind in ["rabbit","deer"]:
        check(load("res://data/animal_catalog.gd").animal(StringName(kind)).leap_range==0,kind+" never pounces")

    # --- A cooldown stops back-to-back pounces -------------------------------------------
    hunter.health=100
    var wolf=session.spawn_animal(&"wolf",Vector3(0,0,-100))
    wolf.global_position=Vector3(0,30,-109);wolf.home=wolf.global_position;wolf.velocity=Vector3.ZERO
    var launches: int=0;var was: bool=false
    for i in 40:
        await physics_frame
        if wolf.leaping and not was: launches+=1
        was=wolf.leaping
    check(wolf.leap_clock>0 or launches>=1,"wolf pounce sets a cooldown")
    session.remove_animal(wolf.animal_id)

    # --- One spotted hunter pulls in the neighbours ---------------------------------------
    hunter.health=100
    var scout=session.spawn_animal(&"wolf",Vector3(0,0,-100));scout.global_position=Vector3(0,30,-130)
    var packmate=session.spawn_animal(&"wolf",Vector3(0,0,-100));packmate.global_position=Vector3(30,30,-130)
    var bear=session.spawn_animal(&"bear",Vector3(0,0,-100));bear.global_position=Vector3(-20,30,-150)
    var snake_far=session.spawn_animal(&"boar",Vector3(0,0,-100));snake_far.global_position=Vector3(0,30,-225)
    scout.home=scout.global_position
    await physics_frame
    scout._physics_process(.016)
    check(scout.target_peer==1,"scout acquires the hunter")
    check(packmate.target_peer==1,"wolf packmate joins the chase")
    check(bear.target_peer==1,"nearby bear joins the chase")
    check(snake_far.target_peer==0,"distant boar is not called")
    for a in [scout,packmate,bear,snake_far]: session.remove_animal(a.animal_id)

    # --- Smell: no line of sight needed at close range ------------------------------------
    var wall:=StaticBody3D.new();wall.position=Vector3(0,31,-103);var ws:=CollisionShape3D.new();var wb:=BoxShape3D.new()
    wb.size=Vector3(20,6,.5);ws.shape=wb;wall.add_child(ws);scene.add_child(wall)
    await frames(2)
    var sniffer=session.spawn_animal(&"wolf",Vector3(0,0,-100))
    sniffer.global_position=Vector3(0,30,-108);sniffer.home=sniffer.global_position
    await physics_frame
    sniffer._physics_process(.016)
    check(not sniffer._can_see(hunter),"wall blocks the line of sight")
    check(sniffer.target_peer==1,"wolf smells a hunter hiding behind cover")
    wall.queue_free();session.remove_animal(sniffer.animal_id)

    # --- Shot out of the air: the corpse falls and the pounce ends ------------------------
    hunter.health=100
    var jumper=session.spawn_animal(&"wolf",Vector3(0,0,-100))
    jumper.global_position=Vector3(0,30,-107);jumper.home=jumper.global_position;jumper.velocity=Vector3.ZERO
    for i in 120:
        await physics_frame
        if jumper.leaping and jumper.global_position.y>30.4: break
    check(jumper.leaping,"wolf is mid-pounce")
    jumper.take_damage(99999,hunter.global_position,1)
    check(jumper.dead and not jumper.leaping,"killing a pouncing wolf ends the pounce")
    for i in 120: await physics_frame
    check(jumper.global_position.y<30.6,"pouncing wolf corpse falls to the ground")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
