extends StaticBody3D
func _ready() -> void:
    var index:=posmod(int(position.x*7+position.z*11),3)
    var visual:=MeshInstance3D.new();visual.mesh=GameArt.nature_mesh("fir_"+"abc"[index]);add_child(visual)
    var c:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.27;shape.height=8
    c.shape=shape;c.position.y=4;add_child(c)
