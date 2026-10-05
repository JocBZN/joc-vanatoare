extends SceneTree
## Standalone fauna galleries; no gameplay world, travel or network fixtures.
## Run with rendering, then optionally: -- --animal-preview-pose=walk
## Supported poses: idle, walk, run, attack. Geometry keeps its game scale;
## each isolated camera fits that animal so small species remain readable.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const SPECIES_NAMES: Dictionary = {
    "rabbit": "Iepure", "deer": "Căprioară", "boar": "Mistreț",
    "wolf": "Lup", "bear": "Urs", "frog": "Broască", "turtle": "Țestoasă",
    "snake": "Șarpe", "crocodile": "Crocodil", "ancient_crocodile": "Crocodil străvechi",
}
const POSE_NAMES: Dictionary = {
    "idle": "Repaus", "walk": "Mers", "run": "Alergare", "attack": "Atac",
}
var gallery: Control
var pose: String = "idle"
var failures: int = 0
var captures: int = 0

func _initialize() -> void:
    call_deferred("run")

func frames(count: int) -> void:
    for frame in count:
        await process_frame

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _mesh_bounds(animal: Node3D) -> AABB:
    var low := Vector3(INF, INF, INF)
    var high := Vector3(-INF, -INF, -INF)
    for mesh in animal.find_children("*", "MeshInstance3D", true, false):
        if not mesh.mesh or not mesh.is_visible_in_tree():
            continue
        var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if not mesh.skeleton.is_empty() else null
        for surface in mesh.mesh.get_surface_count():
            var arrays: Array = mesh.mesh.surface_get_arrays(surface)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
            var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
            var influences: int = bones.size() / maxi(vertices.size(), 1)
            var binds: Array[Transform3D] = []
            if mesh.skin and skeleton and not weights.is_empty():
                for index in mesh.skin.get_bind_count():
                    var bone: int = mesh.skin.get_bind_bone(index)
                    if bone < 0:
                        bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
                    binds.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
            for vertex in vertices.size():
                var point: Vector3 = vertices[vertex]
                var world: Vector3
                if not binds.is_empty():
                    var skinned := Vector3.ZERO
                    for influence in influences:
                        var offset: int = vertex * influences + influence
                        if weights[offset] > 0.0:
                            skinned += (binds[bones[offset]] * point) * weights[offset]
                    world = skeleton.global_transform * skinned
                else:
                    world = mesh.global_transform * point
                low = low.min(world)
                high = high.max(world)
    return AABB(low, high - low)

func _fit_camera(camera: Camera3D, box: AABB, aspect: float) -> void:
    var center: Vector3 = box.get_center()
    var extent: float = maxf(box.size.length(), 1.0)
    camera.position = center + Vector3(2.8, 1.7, -3.8).normalized() * extent * 3.0
    camera.look_at(center)
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    var view: Transform3D = camera.global_transform.affine_inverse()
    for corner in 8:
        var point: Vector3 = box.position + Vector3(
            box.size.x if corner & 1 else 0.0,
            box.size.y if corner & 2 else 0.0,
            box.size.z if corner & 4 else 0.0,
        )
        var local: Vector3 = view * point
        low = low.min(Vector2(local.x, local.y))
        high = high.max(Vector2(local.x, local.y))
    var projected: Vector2 = high - low
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = maxf(projected.y, projected.x / aspect) * 1.18
    camera.near = .01
    camera.far = maxf(100.0, extent * 10.0)
    camera.current = true

func _card(row: HBoxContainer, species: String, index: int, theme: Color) -> Dictionary:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 14)
    row.add_child(column)
    column.add_child(_label(str(SPECIES_NAMES.get(species, species)), 26, Color("203b37")))

    var container := SubViewportContainer.new()
    container.custom_minimum_size = Vector2(350, 710)
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    container.stretch = true
    column.add_child(container)
    var viewport := SubViewport.new()
    viewport.size = Vector2i(350, 710)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_2X
    container.add_child(viewport)
    var studio := Node3D.new()
    viewport.add_child(studio)

    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = theme.lightened(.32)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("dceee5")
    environment.ambient_light_energy = .35
    environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    studio.add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_color = Color("fff1d9")
    sun.light_energy = .68
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    studio.add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-24, 145, 0)
    fill.light_color = Color("c0e4ef")
    fill.light_energy = .15
    studio.add_child(fill)

    var definition: Variant = load("res://data/animals/" + species + ".tres")
    var wildlife_script: Script = load("res://actors/animals/wildlife_animal.gd")
    var animal: Variant = wildlife_script.new()
    animal.definition = definition
    animal.animal_id = 9000 + index
    studio.add_child(animal)
    animal.set_physics_process(false)
    animal.set_process(false)
    animal.behavior = "Rest"
    if animal.label:
        animal.label.hide()
    # Keep background modifier sway from accumulating during the frozen sample.
    if animal.motion:
        animal.motion.active = false
    var action: String = {"idle": "Idle", "walk": "Walk", "run": "Run", "attack": "Attack"}.get(pose, "Idle")
    if not animal.clips.has(action):
        action = "Idle"
    animal._animate(action, true)
    var animation: AnimationPlayer = animal.animation
    var clip_name: String = str(animal.clips.get(action, animal.clips.get("Idle", "")))
    if animation:
        animation.speed_scale = 1.0
        animation.advance(0.0)
        animation.pause()
    else:
        failures += 1
        push_error("No animation player for gallery animal: " + species)

    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(80, 80)
    ground.mesh = plane
    ground.position.y = -.018
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = theme
    ground_material.roughness = .95
    ground.material_override = ground_material
    studio.add_child(ground)

    var camera := Camera3D.new()
    studio.add_child(camera)
    column.add_child(_label(str(POSE_NAMES.get(pose, "Repaus")) if action != "Idle" else "Repaus", 20, Color("5d7770")))
    return {"species": species, "animal": animal, "animation": animation, "clip": clip_name, "camera": camera, "viewport": viewport}

func _gallery(map_id: String) -> void:
    gallery = Control.new()
    gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(gallery)
    var background := ColorRect.new()
    background.color = Color("f4f0e5")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    gallery.add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 45)
    margin.add_theme_constant_override("margin_right", 45)
    margin.add_theme_constant_override("margin_top", 40)
    margin.add_theme_constant_override("margin_bottom", 32)
    gallery.add_child(margin)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 24)
    margin.add_child(content)
    content.add_child(_label("PĂDURE · fauna stilizată" if map_id == "forest" else "MLAȘTINĂ · fauna stilizată", 42, Color("203b37")))
    content.add_child(_label("Hunt Together", 22, Color("6a8174")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(row)
    var species: Array = ["rabbit", "deer", "boar", "wolf", "bear"] if map_id == "forest" else ["frog", "turtle", "snake", "crocodile", "ancient_crocodile"]
    var theme: Color = Color("bccdb6") if map_id == "forest" else Color("b8ccc2")
    var cards: Array[Dictionary] = []
    for index in species.size():
        cards.append(_card(row, species[index], index, theme))
    content.add_child(_label("Modele 3D articulate · materiale toon · proporțiile din joc", 20, Color("6a8174")))
    await frames(8)
    for card in cards:
        var animal: Node3D = card.animal
        var animation: AnimationPlayer = card.animation
        if animation and not str(card.clip).is_empty():
            var clip: Animation = animation.get_animation(card.clip)
            animation.play(card.clip, 0.0)
            animation.seek(clip.length * .32, true)
            animation.advance(0.0)
            animation.pause()
    await frames(2)
    for card in cards:
        var animal: Node3D = card.animal
        var box: AABB = _mesh_bounds(animal)
        _fit_camera(card.camera, box, float(card.viewport.size.x) / float(card.viewport.size.y))
        print("GALLERY_ANIMAL ", card.species, " bounds=", box, " pose=", pose)
    # Allow material/shadow compilation and viewport textures to settle.
    await frames(32)
    await RenderingServer.frame_post_draw
    var pose_suffix: String = "" if pose == "idle" else "_" + pose
    var output: String = "res://docs/animals_" + map_id + "_stylized" + pose_suffix + ".png"
    var saved: Error = root.get_texture().get_image().save_png(output)
    if saved != OK:
        failures += 1
        push_error("Could not save gallery " + output + ": " + str(saved))
    else:
        captures += 1
        print("ANIMAL_PREVIEW_OK ", map_id, " ", ProjectSettings.globalize_path(output))
    gallery.queue_free()
    await frames(5)

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--animal-preview-pose="):
            pose = argument.get_slice("=", 1).to_lower()
    if not POSE_NAMES.has(pose):
        push_error("Unsupported gallery pose: " + pose)
        quit(1)
        return
    root.size = OUTPUT_SIZE
    root.content_scale_size = OUTPUT_SIZE
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    await frames(4)
    await _gallery("forest")
    await _gallery("swamp")
    if captures != 2:
        failures += 1
        push_error("Expected two animal gallery captures; received " + str(captures))
    print("ANIMAL_GALLERY_DONE failures=", failures)
    quit(0 if failures == 0 else 1)
