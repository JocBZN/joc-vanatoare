extends Node3D
## Authored textures and native dressing, with gameplay nodes left in place.
func _ready() -> void:
    GameArt.dress_scene(self)
    $Camp/Floor/Mesh.material_override=GameArt.ground_material()
    $Camp/DirtClearing.material_override=GameArt.pbr("rocky_trail",7)
    GameArt.cinematic($Camp/Environment.environment)
    var rng:=RandomNumberGenerator.new();rng.seed=441
    for index in 1100:
        var point:=Vector3(rng.randf_range(-28,28),.03,rng.randf_range(-28,28))
        if Vector2(point.x,point.z).length()<20: continue
        var node:=MeshInstance3D.new()
        node.mesh=GameArt.nature_mesh("fern_0" if index%40==0 else "grass_"+str(rng.randi_range(3,6)))
        node.position=point;node.rotation.y=rng.randf()*TAU;node.scale=Vector3.ONE*rng.randf_range(.65,1.3)
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
    for index in 16:
        var node:=MeshInstance3D.new();node.mesh=GameArt.nature_mesh("rock_"+str(index%6))
        var angle: float=index*TAU/16;node.position=Vector3(cos(angle)*21,.02,sin(angle)*21)
        node.rotation.y=rng.randf()*TAU;node.scale=Vector3.ONE*rng.randf_range(.3,.65);add_child(node)
    LocaleSettings.changed.connect(func() -> void: GameArt.cinematic($Camp/Environment.environment))
