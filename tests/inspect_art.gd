extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var library=load("res://art/game_art.gd")
    for id in ["fir_a","grass_3","fern_0","rock_0"]:
        var scene=load("res://assets/art/nature/"+id+".glb").instantiate();root.add_child(scene)
        for instance in scene.find_children("*","MeshInstance3D",true,false):
            print("SOURCE ",id," ",instance.transform," ",instance.get_aabb())
            for surface in instance.mesh.get_surface_count():
                var mat=instance.get_active_material(surface)
                print("MAT ",mat," NAME ",mat.resource_name," COLOR ",mat.albedo_texture," ALPHA ",mat.transparency)
        scene.queue_free()
        var mesh=library.nature_mesh(id)
        print("RESULT ",id," ",mesh.get_aabb())
        for surface in mesh.get_surface_count(): print("RESULT MAT ",surface," ",mesh.surface_get_material(surface))
    await process_frame
    quit()
