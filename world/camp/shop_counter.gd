class_name ShopCounter
extends LobbyInteractable
## A counter aboard the Wandering Oak: a shop window in the trunk or the storage
## counter in the cottage. The host still validates every purchase through
## `_at_stall`; the counter only carries its painted name and slogan.

var slogan_key: String=""

func _localize_signs() -> void:
    var title:=get_node_or_null("Title") as Label3D
    if title: title.text=tr(interaction_kind).to_upper()
    var slogan:=get_node_or_null("Slogan") as Label3D
    if slogan: slogan.text=tr(slogan_key)
