extends SceneTree
var checks: int=0
var failures: int=0
var scene
var session
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var hunter=session.local_hunter();hunter.set_physics_process(false);hunter.control_enabled=false
    hunter.global_position=Vector3(0,30,-100);hunter.world_ready=true
    var stage:=StaticBody3D.new();var collision:=CollisionShape3D.new();var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(200,1,200)
    stage.position=Vector3(0,29.5,-100);collision.shape=floor_shape;stage.add_child(collision);scene.add_child(stage)
    session.phase="hunt";await frames(3)
    var art=load("res://art/game_art.gd")
    for id in ["fir_a","fir_b","fir_c","grass_patch_small_a","fern_0","rock_0"]:
        var mesh=art.nature_mesh(id)
        check(mesh.get_surface_count()>0,"authored mesh "+id)
        for surface in mesh.get_surface_count(): check(mesh.surface_get_material(surface)!=null,"textured surface "+id+" "+str(surface))
    check(art.impostor("fir_a").surface_get_array_len(0)==4,"four vertex distant tree surface")
    var forest=load("res://world/forest/forest_map.gd").new();scene.add_child(forest);session.forest=forest
    forest._plant_sector(Vector2i(3,-3))
    var before: Dictionary={}
    for node in forest.vegetation[Vector2i(3,-3)]:
        before[node.multimesh.mesh.get_instance_id()]=node.multimesh.get_instance_transform(0)
        node.queue_free()
    forest.vegetation.erase(Vector2i(3,-3));forest._plant_sector(Vector2i(3,-3))
    var deterministic:=true
    for node in forest.vegetation[Vector2i(3,-3)]:
        deterministic=deterministic and before[node.multimesh.mesh.get_instance_id()].is_equal_approx(node.multimesh.get_instance_transform(0))
    check(deterministic,"regenerated vegetation is deterministic")
    check(hunter.visual.get_node("LeftLeg/Knee")!=null,"hunter has articulated knees")
    check(hunter.visual.get_node("Torso").material_override.normal_enabled,"hunter woven cloth normal map")
    for kind in ["rabbit","deer","boar","wolf","bear"]:
        var animal=session.spawn_animal(StringName(kind),Vector3(0,0,-120))
        animal.global_position=Vector3(0,30,-120);animal.set_physics_process(false)
        check(animal.animation!=null and (animal.clips.has("Run") or animal.clips.has("Walk")),"locomotion animation "+kind)
        check(animal.motion!=null,"additive skeleton modifier "+kind)
        print("RIG ",kind," head=",animal.motion.head," chest=",animal.motion.chest," ears=",animal.motion.ears)
        session.remove_animal(animal.animal_id)
    var wolf=session.spawn_animal(&"wolf",Vector3(0,0,-120));wolf.global_position=Vector3(0,30,-120)
    wolf.set_physics_process(false)
    var wall:=StaticBody3D.new();wall.position=Vector3(0,31,-110)
    var wall_collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,4,1);wall_collision.shape=box;wall.add_child(wall_collision);scene.add_child(wall)
    await frames(3)
    check(not wolf._can_see(hunter),"predator sight blocked by world geometry")
    wolf.hear_noise(hunter.global_position,55);wolf._physics_process(.016)
    check(wolf.target_peer==0 and wolf.behavior=="Investigate","hidden gunshot is investigated without seeing through wall")
    check(wolf.noise_clock>7 and wolf.look_target.distance_to(hunter.global_position+Vector3.UP)<.1,"gunshot location remembered")
    wolf.hear_noise(Vector3(500,30,500),10)
    check(wolf.noise_position==hunter.global_position,"out of range noise ignored")
    wall.queue_free();await frames(3);wolf.global_position=Vector3(0,30,-101.5);wolf.velocity=Vector3.ZERO
    hunter.health=100;wolf.target_peer=0;wolf.attack_clock=0
    wolf._physics_process(.016)
    check(hunter.health==100 and wolf.attack_windup>0,"melee has visible windup")
    wolf._finish_attack(.5)
    check(hunter.health==100-wolf.definition.attack_damage,"melee damage lands after windup")
    var hp: int=hunter.health;wolf._finish_attack(.5)
    check(hunter.health==hp,"one hit per melee swing")
    var data: Dictionary=wolf.snapshot()
    check(data.has("look") and data.has("clock") and data.has("behavior") and data.has("pace"),"replicated animal motion metadata")
    var clone=session.spawn_animal(&"wolf",Vector3(60,0,-100));clone.set_physics_process(false);clone.apply_snapshot(data)
    check(clone.look_target==wolf.look_target and clone.behavior==wolf.behavior,"replica receives focus and behavior")
    session.mode="client";clone.hear_noise(Vector3.ZERO,1000)
    check(clone.noise_clock==0,"client cannot author hearing state")
    session.mode="solo"
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
