class_name TestDeer
extends CharacterBody3D
signal health_changed
signal downed
@export var max_health: int = 36
@export var roam_radius: float = 3.8
@export var respawn_delay: float = 12.0
var health: int = 36
var dead: bool = false
var ai_enabled: bool = true
var home: Vector3
var _target: Vector3
var _wait: float = 2.0
var _flee_time: float = 0.0
var _dead_time: float = 0.0
var _rng := RandomNumberGenerator.new()
@onready var animator: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
    home = global_position
    _target = home
    health = max_health
    _rng.randomize()
    _prepare_materials()
    animator.play("Idle")
    add_to_group("test_animals")

func _prepare_materials() -> void:
    # Old FBX materials contain duplicate IDs. Explicit maps avoid importer ambiguity.
    for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
        var material := StandardMaterial3D.new()
        material.roughness = 0.92
        if mesh.name == "Eyes":
            material.albedo_color = Color("20170e")
        else:
            material.albedo_texture = load("res://assets/animals/deer/doe-head.png" if mesh.name == "Head2" else "res://assets/animals/deer/doe-body.png")
        mesh.material_override = material

func _physics_process(delta: float) -> void:
    if dead:
        _dead_time += delta
        if _dead_time > 2.0:
            $Model.hide()
        if _dead_time >= respawn_delay:
            _try_respawn()
        return
    if not ai_enabled:
        return
    _wait -= delta
    _flee_time = maxf(0.0, _flee_time - delta)
    var offset := _target - global_position
    offset.y = 0.0
    if offset.length() < 0.35:
        velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
        _animate("Idle")
        if _wait <= 0.0:
            _target = home + Vector3(_rng.randf_range(-roam_radius, roam_radius), 0, _rng.randf_range(-roam_radius, roam_radius))
            _wait = _rng.randf_range(3.0, 6.0)
    else:
        var direction := offset.normalized()
        var speed := 4.0 if _flee_time > 0 else 1.35
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 7.0))
        _animate("Run", 1.0 if _flee_time > 0 else 0.4)
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    else:
        velocity.y = 0.0
    move_and_slide()
    if is_on_wall():
        _target = home

func _animate(key: String, speed: float = 1.0) -> void:
    animator.speed_scale = speed
    if animator.current_animation != key:
        animator.play(key, 0.2)

func take_damage(amount: int, source: Vector3) -> bool:
    if dead or amount <= 0:
        return false
    health = maxi(0, health - amount)
    health_changed.emit()
    if health == 0:
        dead = true
        collision_layer = 0
        velocity = Vector3.ZERO
        _dead_time = 0.0
        _animate("Die")
        var loot: LootPickup = preload("res://world/pickups/deer_loot.tscn").instantiate()
        get_parent().add_child(loot)
        loot.global_position = global_position + Vector3(0.0, 0.0, 0.5)
        downed.emit()
    else:
        var away := global_position - source
        away.y = 0
        if away.length_squared() < 0.01:
            away = Vector3.FORWARD
        _target = home + away.normalized() * roam_radius
        _wait = 4.0
        _flee_time = 4.0
    return true

func _try_respawn() -> void:
    # Keep uncollected test drops bounded rather than producing an unlimited pile.
    if get_tree().get_nodes_in_group("loot_pickups").size() >= 4:
        return
    dead = false
    health = max_health
    collision_layer = 4
    global_position = home
    _target = home
    _wait = 2.0
    _flee_time = 0.0
    $Model.show()
    _animate("Idle")
    health_changed.emit()
