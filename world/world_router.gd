class_name WorldRouter
extends Node3D
## Only scenery changes. NetworkSession and the player paths remain stable.
signal progress(value: float)
signal completed(epoch: int)
signal failed(epoch: int)
const PATHS={"lobby":"res://world/lobby/lobby.tscn","forest":"res://world/forest/forest_world.tscn","swamp":"res://world/swamp/swamp_world.tscn"}
var active: Node3D
var active_id: String=""
var job: int=0

func _remove_active() -> void:
    if not is_instance_valid(active): return
    var terrain=map()
    if is_instance_valid(terrain): terrain.cancelled=true
    remove_child(active)
    active.queue_free()
    active=null

func restore_lobby() -> void:
    job+=1
    _remove_active()
    active=load(PATHS.lobby).instantiate()
    active_id="lobby"
    add_child(active)

func prepare(id: String, epoch: int) -> void:
    job+=1
    var ticket:=job
    progress.emit(0.0)
    await get_tree().process_frame
    if ticket!=job: return
    var path: String=PATHS[id]
    var error:=ResourceLoader.load_threaded_request(path,"PackedScene")
    if error!=OK: failed.emit(epoch);return
    var values: Array=[]
    while ResourceLoader.load_threaded_get_status(path,values)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        progress.emit(.03+.08*(float(values[0]) if not values.is_empty() else 0))
        await get_tree().process_frame
        if ticket!=job: return
    if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED: failed.emit(epoch);return
    var packed: PackedScene=ResourceLoader.load_threaded_get(path)
    if ticket!=job: return
    _remove_active()
    active=packed.instantiate()
    active_id=id
    add_child(active)
    if WorldCatalog.is_hunt(id):
        active.build_progress.connect(func(value: float) -> void:
            if ticket==job: progress.emit(.12+.88*value))
        await active.build()
    else:
        await get_tree().physics_frame
    if ticket!=job: return
    progress.emit(1.0)
    completed.emit(epoch)

func map():
    return active.get_node("Swamp" if active_id=="swamp" else "Forest") if WorldCatalog.is_hunt(active_id) and is_instance_valid(active) else null

func hunter_spawn(index: int) -> Vector3:
    return Vector3((index%4)*1.8-2.7,2.1 if active_id=="swamp" else .8,9)

func jeep_spawn() -> Transform3D:
    if active_id=="swamp": return Transform3D(Basis(Vector3.UP,.25),Vector3(-6,2.1,7))
    return Transform3D(Basis(Vector3.UP,.25),Vector3(-6,.6,7)) if active_id=="forest" else Transform3D(Basis(Vector3.UP,.49),Vector3(-9.4,.6,5.2))
