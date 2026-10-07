class_name HunterCameraRig
extends Node3D
## Local first-person ADS or third-person orbit, selected in settings.

signal aim_changed(aiming: bool)

@export var mouse_sensitivity: float = 0.0025
@export var exploration_distance: float = 5.2
@export var aim_distance: float = 2.2
@export var exploration_fov: float = 75.0
@export var aim_fov: float = 55.0
@export var transition_speed: float = 12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var enabled: bool = true
var aiming: bool = false
var view_model
var scope_overlay
var recoil_pitch: float = 0.0
func _ready() -> void:
    view_model=load("res://actors/hunter/first_person_weapon.gd").new();camera.add_child(view_model)
    var layer:=CanvasLayer.new();layer.layer=0;add_child(layer)
    scope_overlay=load("res://ui/hud/scope_overlay.gd").new();layer.add_child(scope_overlay)
func is_first_person() -> bool:
    var hunter=get_parent()
    return hunter.local_player and hunter.health>0 and hunter.seat_index!=0 and LocaleSettings.perspective=="first"
func scope_visible() -> bool:
    var hunter=get_parent()
    return is_first_person() and aiming and hunter.control_enabled and view_model.ads_blend>.85 and EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id).sight_type=="scope"
func set_aiming(value: bool) -> void:
    if aiming==value: return
    aiming=value;aim_changed.emit(aiming)



func _unhandled_input(event: InputEvent) -> void:
    if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if event is InputEventMouseMotion:
        rotation.y -= event.relative.x * mouse_sensitivity
        rotation.x = clampf(
            rotation.x - event.relative.y * mouse_sensitivity,
            deg_to_rad(-80.0),
            deg_to_rad(85.0)
        )


func _process(delta: float) -> void:
    var hunter=get_parent()
    if not enabled:
        view_model.hide();scope_overlay.hide();hunter.visual.show()
        return
    if is_instance_valid(hunter.combat) and not hunter.combat.fired.is_connected(_on_fired):
        hunter.combat.fired.connect(_on_fired)
    set_aiming(hunter.health>0 and hunter.revive_target==0 and hunter.control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("aim"))
    update_camera(delta)

func _on_fired() -> void:
    var hunter=get_parent()
    if not hunter.local_player: return
    recoil_pitch=minf(recoil_pitch+hunter.combat.recoil*deg_to_rad(42.0),deg_to_rad(11.0))

func update_camera(delta: float) -> void:
    var hunter=get_parent()
    var first:=is_first_person()
    var blend:=1-exp(-transition_speed*delta)
    hunter.visual.visible=not first
    position.y=1.62 if first else .85 if hunter.health<=0 else 1.55
    spring_arm.position.x=0 if first else .55
    spring_arm.spring_length=0 if first else lerpf(spring_arm.spring_length,aim_distance if aiming else exploration_distance,blend)
    var definition:=EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id)
    var fov: float=definition.ads_fov if first and aiming else aim_fov if aiming else exploration_fov
    camera.fov=lerpf(camera.fov,fov,blend)
    camera.near=.025 if first else .08
    recoil_pitch=move_toward(recoil_pitch,0.0,delta*deg_to_rad(95.0))
    camera.rotation.x=recoil_pitch
    scope_overlay.visible=scope_visible()
    if scope_overlay.visible: scope_overlay.queue_redraw()


func movement_direction(stick: Vector2) -> Vector3:
    var direction := Basis(Vector3.UP, rotation.y) * Vector3(stick.x, 0.0, stick.y)
    return direction.normalized() if direction.length_squared() > 1.0 else direction


func reset_view() -> void:
    rotation = Vector3(deg_to_rad(-15.0), 0.0, 0.0)
