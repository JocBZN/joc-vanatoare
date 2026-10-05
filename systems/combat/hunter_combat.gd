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
    if hunter.local_player and hunter.control_enabled and Input.is_action_just_pressed("reload"):
        NetworkSession.request_action("reload")
    var weapon:=EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id)
    var trigger:=Input.is_action_pressed("fire") if weapon.automatic else Input.is_action_just_pressed("fire")
    if trigger:
        try_fire()

func try_fire() -> bool:
    if not hunter.control_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or cooldown_left > 0.0:
        return false
    if not hunter.local_player or hunter.seat_index>=0 or hunter.health<=0 or hunter.revive_target>0: return false
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
        _tracer(muzzle,endpoint)
        _impact(endpoint,Vector3.UP)
    _audio.global_position=muzzle
    _audio.stream=_sounds[definition.id]
    _audio.pitch_scale=_rng.randf_range(.96,1.04)
    _audio.play()
    recoil=.14 if definition.pellets>1 else .08
    _flash(muzzle)
    fired.emit()
    if damage>0 and hunter.local_player: hit.emit(damage)

func ray(from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [hunter.get_rid()])
    return hunter.get_world_3d().direct_space_state.intersect_ray(query)

func _tracer(from: Vector3, to: Vector3) -> void:
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_add_vertex(from)
    mesh.surface_add_vertex(to)
    mesh.surface_end()
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = _effect_material(Color(1.0, 0.75, 0.28, 0.7))
    hunter.get_parent().add_child(visual)
    _expire(visual, 0.06)

func _flash(position: Vector3) -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.075
    sphere.height = 0.16
    var visual := MeshInstance3D.new()
    visual.mesh = sphere
    visual.material_override = _effect_material(Color(1.0, 0.8, 0.27, 1.0))
    hunter.get_parent().add_child(visual)
    visual.global_position = position
    var light := OmniLight3D.new()
    visual.add_child(light)
    light.light_color = Color(1.0, 0.74, 0.32)
    light.light_energy = 1.8
    light.omni_range = 4.0
    _expire(visual, 0.055)

func _impact(position: Vector3, normal: Vector3) -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.035
    sphere.height = 0.07
    var visual := MeshInstance3D.new()
    visual.mesh = sphere
    visual.material_override = _effect_material(Color("ebba70"))
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
