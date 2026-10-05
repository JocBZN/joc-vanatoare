extends Node
## Native Godot translations; settings only, separate from hunter progression.
signal changed
var profile_id: String = ""
var language: String = "ro"
var sound_volume: float = 0.65
var cinematic: bool = true
var perspective: String="third"
var graphics: String="medium"
var settings_path: String = "user://settings.cfg"

func _ready() -> void:
    var override_path := OS.get_environment("HUNT_SETTINGS_PATH")
    if not override_path.is_empty():
        settings_path = override_path
    else:
        for argument in OS.get_cmdline_user_args():
            if argument.begins_with("--profile="):
                var slot:=argument.trim_prefix("--profile=").validate_filename().left(24)
                settings_path="user://settings_"+slot+".cfg"
    for locale in ["en", "ro"]:
        var translation := Translation.new()
        translation.locale = locale
        var messages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/" + locale + ".json"))
        for key: String in messages:
            translation.add_message(key, messages[key])
        TranslationServer.add_translation(translation)
    var config := ConfigFile.new()
    if config.load(settings_path) == OK:
        language = str(config.get_value("settings", "language", "ro"))
        sound_volume = clampf(float(config.get_value("settings", "volume", 0.65)), 0.0, 1.0)
        cinematic = bool(config.get_value("settings", "cinematic", true))
    graphics=str(config.get_value("settings","graphics","medium"))
    if graphics not in ["low","medium","high"]: graphics="medium"
    perspective=str(config.get_value("settings","perspective","third"))
    if perspective not in ["third","first"]: perspective="third"
    profile_id = str(config.get_value("settings", "profile_id", ""))
    if profile_id.length() != 32:
        profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
    save_settings()
    if language not in ["en", "ro"]:
        language = "ro"
    TranslationServer.set_locale(language)
    _apply_audio()

func text(key: String, values: Dictionary = {}) -> String:
    return tr(key).format(values)

func set_language(locale: String) -> void:
    if locale not in ["en", "ro"]:
        return
    language = locale
    TranslationServer.set_locale(locale)
    changed.emit()
    save_settings()

func set_volume(value: float) -> void:
    sound_volume = clampf(value, 0.0, 1.0)
    _apply_audio()
    save_settings()

func set_cinematic(enabled: bool) -> void:
    cinematic = enabled
    changed.emit()
    save_settings()

func _apply_audio() -> void:
    AudioServer.set_bus_mute(0, sound_volume < 0.001)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(sound_volume, 0.001)))

func save_settings() -> void:
    # A restricted test environment may not allow the standard user directory.
    var folder := ProjectSettings.globalize_path(settings_path).get_base_dir()
    if not DirAccess.dir_exists_absolute(folder):
        if DirAccess.make_dir_recursive_absolute(folder) != OK:
            return
    var config := ConfigFile.new()
    config.set_value("settings", "profile_id", profile_id)
    config.set_value("settings", "language", language)
    config.set_value("settings", "volume", sound_volume)
    config.set_value("settings", "cinematic", cinematic)
    config.set_value("settings","perspective",perspective)
    config.set_value("settings","graphics",graphics)
    config.save(settings_path)

func set_perspective(value: String) -> void:
    if value not in ["first","third"]: return
    perspective=value;changed.emit();save_settings()

func set_graphics(value: String) -> void:
    if value not in ["low","medium","high"]: return
    graphics=value;changed.emit();save_settings()
