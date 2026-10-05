extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var dest:=OS.get_environment("HUNT_PROP_EXPORT")
    for id in ["rusty_pistol","old_rifle","double_barrel","scrap_blaster","beehive","thunder_tube","backpack_small","backpack_ranger","backpack_expedition"]:
        var model=load("res://actors/equipment/"+id+".tscn").instantiate()
        var document:=GLTFDocument.new();var state:=GLTFState.new()
        document.append_from_scene(model,state);print("EXPORT ",id," ",document.write_to_filesystem(state,dest+"/"+id+".glb"));model.free()
    var model=load("res://actors/vehicles/jeep_model.tscn").instantiate()
    var document:=GLTFDocument.new();var state:=GLTFState.new();document.append_from_scene(model,state)
    print("EXPORT jeep ",document.write_to_filesystem(state,dest+"/jeep.glb"));model.free();quit()
