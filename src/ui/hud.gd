class_name MatchHUD
extends Control
## Интерфейс матча: счёт команд, таймер, обратный отсчёт 3-2-1, экран результата.
## Поддерживает режимы TeamFight и Heist (Добыча).

signal restart_requested

const COLOR_ALLY: Color = Color(0.25, 0.55, 1.0)
const COLOR_ENEMY: Color = Color(1.0, 0.3, 0.3)
const COLOR_SHARD: Color = Color(0.96, 0.68, 0.33)

var _score_team_0: Label
var _score_team_1: Label
var _timer_label: Label
var _mode_label: Label
var _shards_label: Label

var _countdown_label: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_details: Label
var _restart_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()


func _build_ui() -> void:
	# 1. Верхняя панель со счётом и таймером (центрирована сверху для любого разрешения)
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(460, 56)
	top_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = -230.0
	top_bar.offset_right = 230.0
	top_bar.offset_top = 16.0
	top_bar.offset_bottom = 72.0
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.grow_vertical = Control.GROW_DIRECTION_END
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(hbox)

	_score_team_0 = Label.new()
	_score_team_0.text = "0"
	_score_team_0.add_theme_color_override("font_color", COLOR_ALLY)
	_score_team_0.add_theme_font_size_override("font_size", 26)
	hbox.add_child(_score_team_0)

	var vcenter := VBoxContainer.new()
	vcenter.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vcenter)

	_timer_label = Label.new()
	_timer_label.text = "02:00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 22)
	vcenter.add_child(_timer_label)

	_mode_label = Label.new()
	_mode_label.text = "Бой команд"
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_mode_label.add_theme_font_size_override("font_size", 13)
	vcenter.add_child(_mode_label)

	_score_team_1 = Label.new()
	_score_team_1.text = "0"
	_score_team_1.add_theme_color_override("font_color", COLOR_ENEMY)
	_score_team_1.add_theme_font_size_override("font_size", 26)
	hbox.add_child(_score_team_1)

	# Плашка переносимых кристаллов игрока (для Heist) под верхней панелью
	_shards_label = Label.new()
	_shards_label.visible = false
	_shards_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_shards_label.anchor_left = 0.5
	_shards_label.anchor_right = 0.5
	_shards_label.anchor_top = 0.0
	_shards_label.anchor_bottom = 0.0
	_shards_label.offset_left = -160.0
	_shards_label.offset_right = 160.0
	_shards_label.offset_top = 78.0
	_shards_label.offset_bottom = 104.0
	_shards_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shards_label.grow_vertical = Control.GROW_DIRECTION_END
	_shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shards_label.add_theme_color_override("font_color", COLOR_SHARD)
	_shards_label.add_theme_font_size_override("font_size", 16)
	add_child(_shards_label)

	# 2. Обратный отсчёт строго по центру экрана (3, 2, 1, В БОЙ!)
	_countdown_label = Label.new()
	_countdown_label.visible = false
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.anchor_left = 0.5
	_countdown_label.anchor_right = 0.5
	_countdown_label.anchor_top = 0.5
	_countdown_label.anchor_bottom = 0.5
	_countdown_label.offset_left = -200.0
	_countdown_label.offset_right = 200.0
	_countdown_label.offset_top = -80.0
	_countdown_label.offset_bottom = 80.0
	_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 64)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	add_child(_countdown_label)

	# 3. Экран результата матча (победа/поражение/ничья) на весь экран
	_build_result_panel()


func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.anchor_left = 0.0
	_result_panel.anchor_right = 1.0
	_result_panel.anchor_top = 0.0
	_result_panel.anchor_bottom = 1.0
	_result_panel.offset_left = 0.0
	_result_panel.offset_right = 0.0
	_result_panel.offset_top = 0.0
	_result_panel.offset_bottom = 0.0
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 240)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(_result_title)

	_result_details = Label.new()
	_result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_details.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_result_details)

	_restart_button = Button.new()
	_restart_button.text = "ЕЩЁ РАЗ"
	_restart_button.custom_minimum_size = Vector2(160, 48)
	_restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_restart_button.add_theme_font_size_override("font_size", 18)
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	vbox.add_child(_restart_button)


## Обновляет данные интерфейса каждый кадр/тик
func update_hud(world: SimWorld, player: SimBrawler) -> void:
	var mode := world.mode
	if mode == null:
		return

	# 1. Таймер
	var secs_left: int = int(ceil(float(mode.ticks_left) / SimConstants.TICK_RATE))
	_timer_label.text = "%02d:%02d" % [secs_left / 60, secs_left % 60]

	# 2. Счёт
	var s0: int = int(mode.scores.get(0, 0))
	var s1: int = int(mode.scores.get(1, 0))

	if mode is TeamFight:
		var tf := mode as TeamFight
		_score_team_0.text = str(s0)
		_score_team_1.text = str(s1)
		_mode_label.text = "Бой команд (до %d)" % tf.kills_to_win
		_shards_label.visible = false
	elif mode is Heist:
		var heist := mode as Heist
		_score_team_0.text = "💎 %d" % s0
		_score_team_1.text = "💎 %d" % s1
		_mode_label.text = "Добыча (цель: %d)" % heist.target_score
		if player != null:
			var carried: int = Heist.carried(player)
			_shards_label.visible = carried > 0
			_shards_label.text = "Несёшь осколков: %d 💎" % carried

	# 3. Отсчёт
	if mode.phase == GameMode.Phase.COUNTDOWN:
		_countdown_label.visible = true
		var cd_secs := int(ceil(mode.countdown_left(world)))
		if cd_secs > 0:
			_countdown_label.text = str(cd_secs)
		else:
			_countdown_label.text = "В БОЙ!"
	else:
		_countdown_label.visible = false

	# 4. Результат матча
	if mode.is_finished():
		_result_panel.visible = true
		if mode.winner == -1:
			_result_title.text = "НИЧЬЯ"
			_result_title.add_theme_color_override("font_color", Color.WHITE)
		elif mode.winner == player.team:
			_result_title.text = "ПОБЕДА!"
			_result_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		else:
			_result_title.text = "ПОРАЖЕНИЕ"
			_result_title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))

		_result_details.text = "Счёт: %d — %d   (время матча: %d с)" % [
			s0, s1, world.tick / SimConstants.TICK_RATE
		]
	else:
		_result_panel.visible = false
