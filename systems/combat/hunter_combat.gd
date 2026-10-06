class_name HunterCombat
extends Node
## Camera selects the target; muzzle ray enforces actual line of sight.
signal fired
signal hit(damage: int)
var hunter: Hunter
var cooldown_left: float = 0.0
var shots_fired: int = 0
var last_hits: Array[Dictionary] = []
var recoil: float = 0.0
var _sounds: Dictionary = {}
var _audio: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    hunter = get_parent() as Hunter
    _rng.randomize()
    _audio = AudioStreamPlayer3D.new()
    _audio.max_polyphony = 4
    _audio.volume_db = -7.0
    _audio.unit_size = 5.0
    _audio.max_distance = 60.0
    hunter.add_child(_audio)
    for weapon: WeaponDefinition in EquipmentCatalog.WEAPONS:
        _sounds[weapon.id] = load(weapon.fire_sound)

func _physics_process(delta: float) -> void:
    cooldown_left = maxf(0.0, cooldown_left - delta)
    recoil = move_toward(recoil, 0.0, delta * 0.8)
    if hunter.busy() or hunter.harvest_input_guard or NetworkSession.is_busy(hunter.peer_id): return
    if hunter.local_player and hunter.control_enabled and Input.is_action_just_pressed("reload"):
        NetworkSession.request_action("reload")
    if hunter.local_player and hunter.control_enabled:
        if Input.is_action_just_pressed("weapon_slot_1") and hunter.inventory.active_slot!=0:
            NetworkSession.request_action("slot","0")
        elif Input.is_action_just_pressed("weapon_slot_2") and hunter.inventory.active_slot!=1:
            NetworkSession.request_action("slot","1")
    var weapon:=EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id)
    var trigger:=Input.is_action_pressed("fire") if weapon.automatic else Input.is_action_just_pressed("fire")
    if trigger:
        try_fire()

func try_fire() -> bool:
    if not hunter.control_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or cooldown_left > 0.0:
        return false
    if not hunter.local_player or hunter.seat_index==0 or hunter.health<=0 or hunter.revive_target>0 or hunter.busy() or hunter.harvest_input_guard or NetworkSession.is_busy(hunter.peer_id): return false
    if hunter.inventory.reload_remaining>0: return false
    var camera: Camera3D=hunter.camera_rig.camera
    var center:=camera.get_viewport().get_visible_rect().size*.5
    cooldown_left=hunter.inventory.weapon_cooldown(hunter.inventory.equipped_weapon_id)
    NetworkSession.request_shot(camera.project_ray_origin(center),camera.project_ray_normal(center))
    return true

func present_shot(id: String, muzzle: Vector3, endpoints: Array, damage: int) -> void:
    var definition:=EquipmentCatalog.weapon(StringName(id))
    shots_fired+=1
    for endpoint in endpoints:
        _tracer(muzzle,endpoint,definition.effect_color)
        _impact(endpoint,Vector3.UP,definition.effect_color)
    _audio.global_position=muzzle
    _audio.stream=_sounds[definition.id]
    _audio.pitch_scale=_rng.randf_range(.96,1.04)
    _audio.play()
    recoil=clampf(.055+float(definition.damage)*.0032+(.05 if definition.pellets>1 else 0.0),.055,.26)
    _flash(muzzle,(endpoints[0]-muzzle).normalized() if not endpoints.is_empty() else Vector3.FORWARD,definition.effect_color)
    fired.emit()
    if damage>0 and hunter.local_player: hit.emit(damage)

func ray(from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [hunter.get_rid()])
    return hunter.get_world_3d().direct_space_state.intersect_ray(query)

func _tracer(from: Vector3, to: Vector3, color: Color) -> void:
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_add_vertex(from)
    mesh.surface_add_vertex(to)
    mesh.surface_end()
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = _effect_material(Color(color,0.7))
    hunter.get_parent().add_child(visual)
    _expire(visual, 0.06)

func _flash(position: Vector3, direction: Vector3, color: Color) -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.065
    sphere.height = 0.14
    var visual := MeshInstance3D.new()
    visual.mesh = sphere
    visual.material_override = _effect_material(color)
    hunter.get_parent().add_child(visual)
    visual.global_position = position
    var light := OmniLight3D.new()
    visual.add_child(light)
    light.light_color = color
    light.light_energy = 1.75
    light.omni_range = 3.6
    # Subtle muzzle fire: a tight handful of embers, tinted to the weapon's own effect color.
    var forward: Vector3 = direction if direction.length_squared() > 0.001 else Vector3.FORWARD
    var right: Vector3 = forward.cross(Vector3.UP).normalized() if absf(forward.dot(Vector3.UP)) < .98 else Vector3.RIGHT
    var up: Vector3 = right.cross(forward).normalized()
    for i in 5:
        var radius: float = _rng.randf_range(.012, .026)
        var ember := SphereMesh.new()
        ember.radius = radius
        ember.height = radius * 2.0
        var spark := MeshInstance3D.new()
        spark.mesh = ember
        spark.material_override = _effect_material(color.lightened(_rng.randf_range(0,.35)))
        visual.add_child(spark)
        var spread: Vector3 = right * _rng.randf_range(-.06, .06) + up * _rng.randf_range(-.05, .07)
        spark.position = forward * _rng.randf_range(.04, .16) + spread
    _expire(visual, 0.075)

func _impact(position: Vector3, normal: Vector3, color: Color) -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.035
    sphere.height = 0.07
    var visual := MeshInstance3D.new()
    visual.mesh = sphere
    visual.material_override = _effect_material(color.lightened(.2))
    hunter.get_parent().add_child(visual)
    visual.global_position = position + normal * 0.02
    _expire(visual, 0.15)

func _effect_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

func _expire(node: Node, seconds: float) -> void:
    get_tree().create_timer(seconds).timeout.connect(node.queue_free)

func _exit_tree() -> void:
    if is_instance_valid(_audio):
        _audio.stop()
        _audio.stream=null
