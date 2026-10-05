extends Node3D

@onready var warm_light: OmniLight3D = $WarmLight
@onready var upper_light: OmniLight3D = $UpperLight
var elapsed: float = 0.0


func _process(delta: float) -> void:
    elapsed += delta
    var flicker := sin(elapsed * 5.1) * 0.12 + sin(elapsed * 9.7) * 0.06
    warm_light.light_energy = 2.4 + flicker
    upper_light.light_energy = 1.1 + flicker * 0.4
