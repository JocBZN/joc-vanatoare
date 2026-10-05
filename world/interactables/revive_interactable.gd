extends LobbyInteractable
func _ready() -> void:
    interaction_kind="revive";interaction_range=2.8
    super._ready()
func target_peer() -> int: return get_parent().peer_id
func can_interact() -> bool:
    var hunter=get_parent()
    return hunter.health<=0 and hunter.world_ready and hunter.peer_id!=NetworkSession.local_id() and NetworkSession.phase!="loading"
func interaction_position() -> Vector3:
    return get_parent().visual.to_global(Vector3(0,.8,0))
func localized_name() -> String:
    var hunter=get_parent()
    return LocaleSettings.text("REVIVE_PROMPT",{"name":hunter.player_name,"n":roundi(hunter.revive_progress*100)})
