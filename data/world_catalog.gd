class_name WorldCatalog
extends RefCounted
const HUNTS = ["forest", "swamp", "ocean"]
static func is_hunt(id: String) -> bool: return id in HUNTS
static func title_key(id: String) -> String: return "MAP_OCEAN" if id == "ocean" else "MAP_SWAMP" if id == "swamp" else "MAP_FOREST"
static func name_key(id: String) -> String: return "OCEAN" if id == "ocean" else "SWAMP" if id == "swamp" else "FOREST" if id == "forest" else "LOBBY_NAME"
