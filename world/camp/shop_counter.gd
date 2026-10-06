class_name ShopCounter
extends LobbyInteractable
## A counter aboard the Mammoth base, staffed by a Shopkeeper. The host still
## validates every purchase through `_at_stall`; the keeper is only the face.

var keeper: Shopkeeper
var slogan_key: String=""

func localized_name() -> String:
    if not is_instance_valid(keeper): return tr(interaction_kind)
    return LocaleSettings.text("SHOP_PROMPT",{"shop":tr(interaction_kind),"npc":keeper.display_name()})

func _localize_signs() -> void:
    var title:=get_node_or_null("Title") as Label3D
    if title: title.text=tr(interaction_kind).to_upper()
    var slogan:=get_node_or_null("Slogan") as Label3D
    if slogan: slogan.text=tr(slogan_key)

## The keeper shouts at whoever opened the shop; the line also heads the shop window.
func greet_customer() -> String:
    if not is_instance_valid(keeper): return ""
    var line: String=keeper.say()
    return LocaleSettings.text("SHOP_QUOTE",{"line":line,"name":keeper.display_name()}) if line!="" else ""
