extends Node
## Пользовательские настройки (звук, чувствительность, графика).
## Полная реализация — задача G-07 (Codex).

const SETTINGS_PATH: String = "user://settings.cfg"

var values: Dictionary = {
	"audio/master": 1.0,
	"controls/sensitivity": 1.0,
	"graphics/quality": "medium",
}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key: String in values.keys():
		var parts := key.split("/")
		values[key] = cfg.get_value(parts[0], parts[1], values[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in values.keys():
		var parts := key.split("/")
		cfg.set_value(parts[0], parts[1], values[key])
	cfg.save(SETTINGS_PATH)
	Events.settings_changed.emit()
