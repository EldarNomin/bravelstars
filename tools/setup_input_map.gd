extends SceneTree
## Пересоздаёт карту ввода для ПК-отладки в project.godot.
## Запуск: godot --headless -s tools/setup_input_map.gd

const KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"auto_attack": [KEY_E],
	"use_super": [KEY_SPACE],
}
const MOUSE: Dictionary = {
	"attack": MOUSE_BUTTON_LEFT,
	"use_super": MOUSE_BUTTON_RIGHT,
}


func _init() -> void:
	for action: String in KEYS.keys():
		var events: Array = []
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = key
			events.append(ev)
		if MOUSE.has(action):
			events.append(_mouse(MOUSE[action]))
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.set_setting("input/attack", {"deadzone": 0.2, "events": [_mouse(MOUSE["attack"])]})
	ProjectSettings.save()
	quit()


func _mouse(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.device = -1
	ev.button_index = button
	return ev
