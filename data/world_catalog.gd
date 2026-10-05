class_name WorldCatalog
extends RefCounted
const HUNTS = ["forest", "swamp"]
static func is_hunt(id: String) -> bool: return id in HUNTS
static func title_key(id: String) -> String: return "MAP_SWAMP" if id == "swamp" else "MAP_FOREST"
static func name_key(id: String) -> String: return "SWAMP" if id == "swamp" else "FOREST" if id == "forest" else "LOBBY_NAME"
