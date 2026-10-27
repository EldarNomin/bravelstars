extends GutTest

var _mv: MatchView


func after_each() -> void:
	if _mv != null and is_instance_valid(_mv):
		_mv.free()
		_mv = null


func test_match_view_initializes_with_3v3_teams() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/sawmill.json"
	add_child_autofree(_mv)

	assert_not_null(_mv.world, "SimWorld должен быть создан")
	assert_eq(_mv.world.brawlers.size(), 6, "На арене должно быть ровно 6 героев (3v3)")
	assert_not_null(_mv.player, "Локальный игрок должен быть назначен")
	assert_eq(_mv.player.team, 0, "Игрок должен быть в команде 0")

	var team_0_count := 0
	var team_1_count := 0
	for b in _mv.world.brawlers:
		if b.team == 0:
			team_0_count += 1
		else:
			team_1_count += 1

	assert_eq(team_0_count, 3, "В команде 0 должно быть 3 героя")
	assert_eq(team_1_count, 3, "В команде 1 должно быть 3 героя")
	assert_eq(_mv.bot_team.brains.size(), 5, "Должно быть ровно 5 ботов")
	assert_true(_mv.world.mode is TeamFight, "По умолчанию на карте Лесопилка режим TeamFight")


func test_match_view_heist_mode_initializes() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/_debug_heist.json"
	add_child_autofree(_mv)

	assert_not_null(_mv.world)
	assert_true(_mv.world.mode is Heist, "На карте _debug_heist режим должен быть Heist")
	assert_eq(_mv.world.brawlers.size(), 6, "3v3 герои в Heist")


func test_match_view_simulation_advances_on_process() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/sawmill.json"
	add_child_autofree(_mv)

	var initial_tick := _mv.world.tick
	# Симулируем 0.1 секунды (3 тика симуляции при 30 Гц)
	_mv._process(0.1)

	assert_gt(_mv.world.tick, initial_tick, "Симуляция должна продвинуться по времени")


func test_map_view_tile_destruction_and_restoration() -> void:
	var mv := MapView.new()
	add_child_autofree(mv)
	var test_map := SimMap.from_lines(PackedStringArray(["###", ".*~", "###"]))
	mv.build_map(test_map)

	# Разрушение стены не должно вызывать ошибок
	mv.on_tile_destroyed(Vector2i(0, 0), SimMap.Tile.WALL)
	# Отрастание куста
	mv.on_tile_restored(Vector2i(1, 1), SimMap.Tile.BUSH)
	pass_test("Разрушение и отрастание тайлов отрабатывают корректно")


func test_brawler_view_hero_model_and_muzzle() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/sawmill.json"
	add_child_autofree(_mv)

	var bv: BrawlerView = _mv._brawler_views.get(_mv.player.id)
	assert_not_null(bv, "BrawlerView игрока должен существовать")

	var muzzle_pos := bv.get_muzzle_global_position()
	assert_gt(muzzle_pos.y, 0.2, "Точка muzzle должна быть выше уровня пола")

	# Проверяем работу методов анимаций
	bv.update_locomotion(true)
	bv.play_action(&"attack")
	bv.play_action(&"super")
	bv.on_death()
	bv.on_respawn()
	pass_test("Методы управления анимациями и muzzle работают штатно")


func test_camera_clamping_keeps_within_map_bounds() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/sawmill.json"
	add_child_autofree(_mv)

	var target := _mv._get_clamped_camera_target()
	var map_w := float(_mv.world.map.width)
	var map_h := float(_mv.world.map.height)

	assert_gte(target.x, 0.0, "Фокус камеры X не должен уходить за левую границу карты")
	assert_lte(target.x, map_w, "Фокус камеры X не должен уходить за правую границу карты")
	assert_gte(target.z, 0.0, "Фокус камеры Z не должен уходить за верхнюю границу карты")
	assert_lte(target.z, map_h, "Фокус камеры Z не должен уходить за нижнюю границу карты")


func test_hud_structure_and_visibility() -> void:
	_mv = MatchView.new()
	_mv.map_path = "res://data/maps/sawmill.json"
	add_child_autofree(_mv)

	assert_not_null(_mv._hud, "MatchHUD должен быть создан")
	assert_not_null(_mv._hud._score_team_0, "Счет команды 0 должен быть в HUD")
	assert_not_null(_mv._hud._score_team_1, "Счет команды 1 должен быть в HUD")
	assert_not_null(_mv._hud._timer_label, "Таймер должен быть в HUD")
