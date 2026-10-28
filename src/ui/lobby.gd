class_name Lobby
extends Control
## Главный экран игры (Lobby):
## - Выбор героя из 3 карточек (Рысь, Наковальня, Шишка) с описанием
## - Выбор игрового режима (Бой команд / Добыча)
## - Выбор сложности ботов (Лёгкие / Обычные / Сложные)
## - Кнопка «В БОЙ!» формирует MatchConfig и запускает match.tscn

signal battle_started(config: MatchConfig)

const COLOR_BG: Color = Color(0.12, 0.14, 0.18)
const COLOR_CARD_DEFAULT: Color = Color(0.18, 0.22, 0.28)
const COLOR_CARD_SELECTED: Color = Color(0.22, 0.35, 0.55)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 0.84, 0.0)  ## Золото
const COLOR_ACCENT_GREEN: Color = Color(0.28, 0.73, 0.47)
const COLOR_ACCENT_AMBER: Color = Color(0.96, 0.68, 0.33)

var selected_hero: StringName = &"lynx"
var selected_mode: StringName = &"teamfight"
var selected_difficulty: MatchConfig.Difficulty = MatchConfig.Difficulty.NORMAL

var _hero_cards: Dictionary = {}  ## hero_id -> Button
var _mode_buttons: Dictionary = {}  ## mode_id -> Button
var _diff_buttons: Dictionary = {}  ## difficulty -> Button
var _last_result_label: Label
var _battle_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()
	_update_selections()
	_update_last_result()


func _build_ui() -> void:
	# 1. Тёмный фон
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_vbox)

	# 2. Заголовок
	var title_box := HBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(title_box)

	var title := Label.new()
	title.text = "BRAVEL STARS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOR_BORDER_SELECTED)
	title_box.add_child(title)

	# Плашка последнего результата
	_last_result_label = Label.new()
	_last_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_result_label.add_theme_font_size_override("font_size", 15)
	_last_result_label.visible = false
	main_vbox.add_child(_last_result_label)

	# 3. Карточки героев (Рысь, Наковальня, Шишка)
	var heroes_box := HBoxContainer.new()
	heroes_box.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes_box.add_theme_constant_override("separation", 20)
	main_vbox.add_child(heroes_box)

	for h_id: StringName in MatchConfig.HEROES:
		var card := _create_hero_card(h_id)
		heroes_box.add_child(card)
		_hero_cards[h_id] = card

	# 4. Ряд настроек: Режим и Сложность
	var options_box := HBoxContainer.new()
	options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	options_box.add_theme_constant_override("separation", 48)
	main_vbox.add_child(options_box)

	# Выбор режима
	var mode_vbox := VBoxContainer.new()
	mode_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_vbox.add_theme_constant_override("separation", 6)
	options_box.add_child(mode_vbox)

	var mode_title := Label.new()
	mode_title.text = "РЕЖИМ"
	mode_title.add_theme_font_size_override("font_size", 14)
	mode_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	mode_vbox.add_child(mode_title)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 10)
	mode_vbox.add_child(mode_hbox)

	var btn_tf := _create_option_button("Бой команд", func() -> void: select_mode(&"teamfight"))
	mode_hbox.add_child(btn_tf)
	_mode_buttons[&"teamfight"] = btn_tf

	var btn_heist := _create_option_button("Добыча 💎", func() -> void: select_mode(&"heist"))
	mode_hbox.add_child(btn_heist)
	_mode_buttons[&"heist"] = btn_heist

	# Выбор сложности
	var diff_vbox := VBoxContainer.new()
	diff_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_vbox.add_theme_constant_override("separation", 6)
	options_box.add_child(diff_vbox)

	var diff_title := Label.new()
	diff_title.text = "БОТЫ"
	diff_title.add_theme_font_size_override("font_size", 14)
	diff_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	diff_vbox.add_child(diff_title)

	var diff_hbox := HBoxContainer.new()
	diff_hbox.add_theme_constant_override("separation", 8)
	diff_vbox.add_child(diff_hbox)

	var btn_easy := _create_option_button(
		"Лёгкие",
		func() -> void: select_difficulty(MatchConfig.Difficulty.EASY)
	)
	diff_hbox.add_child(btn_easy)
	_diff_buttons[MatchConfig.Difficulty.EASY] = btn_easy

	var btn_norm := _create_option_button(
		"Обычные",
		func() -> void: select_difficulty(MatchConfig.Difficulty.NORMAL)
	)
	diff_hbox.add_child(btn_norm)
	_diff_buttons[MatchConfig.Difficulty.NORMAL] = btn_norm

	var btn_hard := _create_option_button(
		"Сложные",
		func() -> void: select_difficulty(MatchConfig.Difficulty.HARD)
	)
	diff_hbox.add_child(btn_hard)
	_diff_buttons[MatchConfig.Difficulty.HARD] = btn_hard

	# 5. Кнопка «В БОЙ!» (крупная, пальцем)
	_battle_button = Button.new()
	_battle_button.text = "В БОЙ!"
	_battle_button.custom_minimum_size = Vector2(260, 56)
	_battle_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_battle_button.add_theme_font_size_override("font_size", 26)
	_battle_button.add_theme_color_override("font_color", Color.WHITE)
	_battle_button.pressed.connect(start_battle)
	main_vbox.add_child(_battle_button)


func _create_hero_card(hero_id: StringName) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 140)
	btn.toggle_mode = false

	var data := MatchSetup.hero(hero_id)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	btn.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = data.display_name if data != null else str(hero_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	var hp_val := data.max_hp if data != null else 0
	var spd_val := data.move_speed if data != null else 0.0
	stats_lbl.text = "HP: %d   •   Скорость: %.1f" % [hp_val, spd_val]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	vbox.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = data.description if data != null else ""
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(280, 48)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(desc_lbl)

	btn.pressed.connect(func() -> void: select_hero(hero_id))
	return btn


func _create_option_button(label_text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(140, 48)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(on_press)
	return btn


func select_hero(hero_id: StringName) -> void:
	selected_hero = hero_id
	_update_selections()


func select_mode(mode_id: StringName) -> void:
	selected_mode = mode_id
	_update_selections()


func select_difficulty(diff: MatchConfig.Difficulty) -> void:
	selected_difficulty = diff
	_update_selections()


func _update_selections() -> void:
	# Подсветка карточек героев
	for h_id: StringName in _hero_cards.keys():
		var btn: Button = _hero_cards[h_id]
		var is_selected := h_id == selected_hero
		var col := COLOR_CARD_SELECTED if is_selected else COLOR_CARD_DEFAULT
		btn.modulate = Color(1.2, 1.2, 1.2) if is_selected else Color(0.8, 0.8, 0.85)

	# Подсветка кнопок режима
	for m_id: StringName in _mode_buttons.keys():
		var btn: Button = _mode_buttons[m_id]
		var is_selected := m_id == selected_mode
		btn.modulate = Color(1.0, 1.0, 0.2) if is_selected else Color(0.75, 0.75, 0.8)

	# Подсветка кнопок сложности
	for d_val: MatchConfig.Difficulty in _diff_buttons.keys():
		var btn: Button = _diff_buttons[d_val]
		var is_selected := d_val == selected_difficulty
		btn.modulate = Color(0.4, 1.0, 0.5) if is_selected else Color(0.75, 0.75, 0.8)


func _update_last_result() -> void:
	if not has_node("/root/Game"):
		return
	var res: Dictionary = get_node("/root/Game").get("last_result")
	if res.is_empty():
		_last_result_label.visible = false
		return

	_last_result_label.visible = true
	var win: bool = res.get("win", false)
	var win_str := "ПОБЕДА" if win else "ПОРАЖЕНИЕ"
	var col := COLOR_ACCENT_GREEN if win else Color(0.9, 0.3, 0.3)
	var s0: int = res.get("score_0", 0)
	var s1: int = res.get("score_1", 0)
	var kills: int = res.get("kills", 0)
	var deaths: int = res.get("deaths", 0)

	_last_result_label.text = "Предыдущий матч: %s (%d — %d)   •   Убийств: %d   •   Смертей: %d" % [
		win_str, s0, s1, kills, deaths
	]
	_last_result_label.add_theme_color_override("font_color", col)


## Собирает актуальный MatchConfig по текущим выборам в меню
func get_match_config() -> MatchConfig:
	var maps := MatchConfig.maps_for_mode(selected_mode)
	var chosen_map: String = ""
	if not maps.is_empty():
		chosen_map = maps[randi() % maps.size()]

	var cfg := MatchConfig.make(selected_mode, selected_hero, chosen_map)
	cfg.difficulty = selected_difficulty
	return cfg


## Запускает матч по текущему конфигу
func start_battle() -> void:
	var cfg := get_match_config()
	if has_node("/root/Game"):
		get_node("/root/Game").next_match = cfg
	battle_started.emit(cfg)
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")
