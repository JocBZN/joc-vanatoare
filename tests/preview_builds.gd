extends SceneTree
## Every truck build, from the front, side and rear, with the galleon mid-unfold and deployed
## and the glass sphere lowered. Usage: godot --path . --script res://tests/preview_builds.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var truck
var out: String="res://docs"
var hold: float=0.0
var hold_sphere: float=0.0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func shot(name_value: String, from: Vector3, to: Vector3, fov: float=62.0) -> void:
    camera.current=true;camera.fov=fov
    if hold>0.0: truck.boat_deploy=hold;truck._deploy_shown=hold;truck.sphere_deploy=hold_sphere;truck._sphere_shown=hold_sphere;for i in 2: truck._update_kits(.05)
    camera.global_position=truck.to_global(from);camera.look_at(truck.to_global(to),Vector3.UP)
    await frames(4)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("BUILD_SHOT ",name_value)
func settle(d: float,sphere: float=0.0) -> void:
    truck.boat_deploy=d;truck._deploy_shown=d;truck.sphere_deploy=sphere;truck._sphere_shown=sphere
    hold=d;hold_sphere=sphere
    for i in 8: truck._update_kits(.1)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    var hunter=scene.hunter
    hunter.control_enabled=false;hunter.set_physics_process(false)
    truck=session.jeep
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=900
    for i in 60: await physics_frame
    hunter.global_position=Vector3(-60,0,60)
    for id in TruckUpgrades.ORDER: session.truck_state[String(id)]=TruckUpgrades.max_level(id)
    truck.set_upgrades(session.truck_state)
    truck.freeze=true
    await frames(5)
    await shot("b0_land_side",Vector3(-22,5,0),Vector3(0,5,1),58)
    await shot("b1_bull",Vector3(-5,3,-16),Vector3(0,2,-8.5),55)
    await shot("b2_tower",Vector3(-7,15,6),Vector3(0,13.2,0),55)
    await shot("b3_roof",Vector3(-6,8,5),Vector3(0,4,.5),60)
    await shot("b4_rear_carrots",Vector3(7,4,14),Vector3(0,1.4,6.4),55)
    await shot("b5_horn",Vector3(-4,9,12),Vector3(1,7.6,2.7),55)
    truck.rotor_on=true
    for i in 40: truck._update_kits(.05)
    await shot("b6_rotor",Vector3(-12,18,10),Vector3(0,15.5,0),60)
    truck.rotor_on=false
    for beat in [[.25,"b7_unfold_a"],[.5,"b8_unfold_b"],[.75,"b9_unfold_c"]]:
        truck.boat_deploy=beat[0];truck._deploy_shown=beat[0]
        for i in 3: truck._update_kits(.05)
        await shot(beat[1],Vector3(-26,9,-14),Vector3(0,2.5,0),62)
    truck.floating=true
    settle(1.0)
    await shot("c0_galleon_3q",Vector3(-26,9,-14),Vector3(0,2.5,0),62)
    await shot("c1_galleon_side",Vector3(-30,6,2),Vector3(0,2.5,1),62)
    await shot("c2_bow_duck",Vector3(-8,6,-20),Vector3(0,3,-10),58)
    await shot("c3_aft_terrace",Vector3(-14,9,20),Vector3(0,1.6,10.5),62)
    await shot("c4_aft_close",Vector3(1,12,19),Vector3(0,1.6,9.5),60)
    for i in 8: truck._host_extras(1.0)
    settle(1.0,1.0)
    truck.global_position+=Vector3(0,8,0)
    await shot("c5_sphere",Vector3(-8,-.5,-5),Vector3(0,-1.3,1.7),60)
    await shot("c5b_sphere_side",Vector3(-9,-2.5,1.7),Vector3(0,-1.2,1.7),50)
    await shot("c6_all_aerial",Vector3(-18,16,-6),Vector3(0,2,3),66)
    print("BUILDS_PREVIEW_DONE")
    scene.queue_free();await frames(5);quit()
