extends "res://tests/preview_water.gd"
## Optional A/B of the real material, with all diagnostic images outside deliverables.
func run() -> void:
    output_dir="res://work/diagnostics"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--diagnostic-out="): output_dir=argument.trim_prefix("--diagnostic-out=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    root.size=Vector2i(1440,900);root.content_scale_size=root.size
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    root.get_node("LocaleSettings").cinematic=false;root.get_node("LocaleSettings").changed.emit()
    await frames(20);scene.menu.resume()
    camera=Camera3D.new();scene.add_child(camera);camera.far=1100;camera.fov=63
    if not await travel("forest"): quit(1);return
    scene.hunter.global_position=Vector3(0,1,0)
    camera.position=Vector3(190,-.8,162);camera.look_at(Vector3(190,session.forest.height_at(190,160),160))
    session.forest.set_process(false)
    await frames(30);await capture("sand_baseline")
    session.forest.water_material.set_shader_parameter("refraction_strength",0)
    await frames(10);await capture("sand_no_refraction")
    session.forest.water_material.set_shader_parameter("wave_strength",0)
    session.forest.water_material.set_shader_parameter("normal_strength",0)
    await frames(10);await capture("sand_flat_water")
    session.forest.get_node("Lake").hide()
    await frames(10);await capture("sand_bed_only")
    var ground=session.forest.get_child(0)
    var original=ground.material_override
    var material=original.duplicate()
    var shader:=Shader.new()
    var code: String=original.shader.code
    shader.code=code.replace("NORMAL = normalize((VIEW_MATRIX * vec4(sand_normal, 0.0)).xyz);","NORMAL = normalize((VIEW_MATRIX * vec4(vec3(0.0,1.0,0.0), 0.0)).xyz);")
    material.shader=shader;ground.material_override=material
    await frames(10);await capture("sand_constant_normal")
    shader=Shader.new();shader.code=code.replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
    material.shader=shader
    await frames(10);await capture("sand_shader_unlit")
    shader=Shader.new();shader.code=code.replace("float grain = sediment_grain(world.xz, 52.0);","float grain = 0.5;").replace("float ripple_visibility = 1.0 - smoothstep(0.5, 2.0, fwidth(phase));","float ripple_visibility = 1.0;")
    material.shader=shader
    await frames(30);await capture("sand_no_derivatives")
    shader=Shader.new();shader.code=code.replace("float grain = sediment_grain(world.xz, 52.0);","float grain = 0.5;").replace("float broad = sediment_noise(world.xz * 0.38);","float broad = 0.5;").replace("float medium = sediment_noise(world.xz * 2.1);","float medium = 0.5;").replace("float ripple_visibility = 1.0 - smoothstep(0.5, 2.0, fwidth(phase));","float ripple_visibility = 1.0;")
    material.shader=shader
    await frames(30);await capture("sand_no_noise")
    var plain:=StandardMaterial3D.new();plain.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;plain.albedo_color=Color(.72,.65,.5)
    ground.material_override=plain
    await frames(10);await capture("sand_plain_bed")
    ground.material_override=original
    print("SEDIMENT_DIAGNOSTIC_DONE")
    scene.queue_free();await frames(8);quit(0)
