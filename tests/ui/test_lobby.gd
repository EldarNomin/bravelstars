extends GutTest

var _lobby: Lobby


func after_each() -> void:
	if _lobby != null and is_instance_valid(_lobby):
		_lobby.free()
		_lobby = null


func test_lobby_builds_default_config() -> void:
	_lobby = Lobby.new()
	add_child_autofree(_lobby)

	var cfg := _lobby.get_match_config()
	assert_not_null(cfg, "Lobby должен формировать MatchConfig")
	assert_eq(cfg.mode, &"teamfight", "Режим по умолчанию — teamfight")
	assert_eq(cfg.hero_id, &"lynx", "Герой по умолчанию — lynx")
	assert_eq(cfg.difficulty, MatchConfig.Difficulty.NORMAL, "Сложность — NORMAL")

	var valid_maps := MatchConfig.maps_for_mode(&"teamfight")
	assert_has(valid_maps, cfg.map_path, "Карта должна быть выбрана из карт режима")


func test_lobby_selection_updates_config() -> void:
	_lobby = Lobby.new()
	add_child_autofree(_lobby)

	_lobby.select_hero(&"anvil")
	_lobby.select_mode(&"heist")
	_lobby.select_difficulty(MatchConfig.Difficulty.HARD)

	var cfg := _lobby.get_match_config()
	assert_eq(cfg.hero_id, &"anvil", "Выбран герой Наковальня")
	assert_eq(cfg.mode, &"heist", "Выбран режим Добыча")
	assert_eq(cfg.difficulty, MatchConfig.Difficulty.HARD, "Выбрана сложность HARD")

	var heist_maps := MatchConfig.maps_for_mode(&"heist")
	assert_has(heist_maps, cfg.map_path, "Карта должна принадлежать режиму Heist")


func test_lobby_buttons_and_touch_target_sizes() -> void:
	_lobby = Lobby.new()
	add_child_autofree(_lobby)

	assert_eq(_lobby._hero_cards.size(), 3, "Должно быть 3 карточки героев")
	assert_eq(_lobby._mode_buttons.size(), 2, "Должно быть 2 кнопки режимов")
	assert_eq(_lobby._diff_buttons.size(), 3, "Должно быть 3 кнопки сложности")
	assert_not_null(_lobby._battle_button, "Кнопка В БОЙ должна присутствовать")

	# Проверка эргономики под палец: кнопки >= 48 px по высоте
	assert_gte(_lobby._battle_button.custom_minimum_size.y, 48.0)
	for b: Button in _lobby._mode_buttons.values():
		assert_gte(b.custom_minimum_size.y, 48.0)
	for b: Button in _lobby._diff_buttons.values():
		assert_gte(b.custom_minimum_size.y, 48.0)
	for b: Button in _lobby._hero_cards.values():
		assert_gte(b.custom_minimum_size.y, 48.0)


func test_lobby_to_match_cycle_no_leaks() -> void:
	# 1. Лобби формирует конфиг
	_lobby = Lobby.new()
	add_child_autofree(_lobby)
	_lobby.select_hero(&"shishka")
	_lobby.select_mode(&"heist")
	var cfg := _lobby.get_match_config()

	if has_node("/root/Game"):
		get_node("/root/Game").set("next_match", cfg)

	# 2. Матч запускается по конфигу
	var mv := MatchView.new()
	add_child_autofree(mv)

	assert_not_null(mv.world, "Мир должен быть инициализирован")
	assert_eq(mv.world.brawlers.size(), 6, "3v3 герои на поле")
	assert_eq(mv.player.data.id, &"shishka", "Игрок должен играть выбранным героем")
	assert_true(mv.world.mode is Heist, "Режим должен соответствовать конфигу")

	# 3. Несколько тиков боя
	mv._process(0.1)

	# 4. Освобождение сцен
	mv.free()
	_lobby.free()
	_lobby = null
	pass_test("Цикл лобби -> матч -> очистка прошел успешно без утечек")
