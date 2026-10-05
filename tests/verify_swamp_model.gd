extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var stage:=Node3D.new();root.add_child(stage);current_scene=stage
    var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("293a32");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.9;stage.add_child(env)
    var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1;stage.add_child(sun)
    var animal=load("res://actors/animals/wildlife_animal.gd").new();animal.definition=load("res://data/animals/crocodile.tres");animal.animal_id=102;stage.add_child(animal);animal.set_physics_process(false)
    var camera:=Camera3D.new();camera.position=Vector3(3,1.3,-3);stage.add_child(camera);camera.look_at(Vector3.UP*.4);camera.current=true
    for i in 60: await process_frame
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/swamp_crocodile_rig.png")
    animal.animation.stop();var skeleton: Skeleton3D=animal.model.find_children("*","Skeleton3D",true,false)[0];skeleton.reset_bone_poses()
    for i in 10: await process_frame
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/swamp_crocodile_rest.png")
    quit()
