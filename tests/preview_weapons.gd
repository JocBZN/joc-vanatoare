extends SceneTree
## One-off visual QA for the sourced weapon viewmodels; not part of the shipped suite.
var scene
var session
var helper

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame

func view(aim: bool) -> void:
    if aim: Input.action_press("aim")
    else: Input.action_release("aim")
    for i in 30:
        await physics_frame

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");helper=session.local_hunter();scene.menu.resume()
    session.set_physics_process(false);helper.set_physics_process(false)
    root.get_node("LocaleSettings").set_perspective("first")
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    helper.global_position=fire.global_position+Vector3(-14,.5,-4)
    helper.control_enabled=true
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    await frames(6)
    for weapon_id in ["rusty_pistol","old_rifle","double_barrel","scrap_blaster","beehive","sniper_rifle","thunder_tube","revolver","ak_rifle","railgun","raygun","chain_smg","nova_shotgun"]:
        helper.inventory.owned_weapons.append(StringName(weapon_id))
        helper.inventory.equipped_weapon_id=StringName(weapon_id)
        helper.inventory.loadout[0]=StringName(weapon_id)
        helper.inventory.changed.emit()
        await frames(4)
        await view(false)
        await RenderingServer.frame_post_draw
        var hip_path: String="res://work/weapon_sources/preview_"+weapon_id+"_hip.png"
        root.get_texture().get_image().save_png(hip_path)
        await view(true)
        await RenderingServer.frame_post_draw
        var ads_path: String="res://work/weapon_sources/preview_"+weapon_id+"_ads.png"
        root.get_texture().get_image().save_png(ads_path)
        print("CAPTURED ", weapon_id, " -> ", ProjectSettings.globalize_path(hip_path), " / ads")
    print("WEAPON_PREVIEW_DONE")
    quit(0)
