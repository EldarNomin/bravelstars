extends GutTest


func test_parse_tiles_spawns_markers() -> void:
	var m := SimMap.from_lines(PackedStringArray(["1.#X", "*~G2"]))
	assert_eq(m.width, 4)
	assert_eq(m.height, 2)
	assert_eq(m.get_tile(2, 0), SimMap.Tile.WALL)
	assert_eq(m.get_tile(3, 0), SimMap.Tile.HARD_WALL)
	assert_eq(m.get_tile(0, 1), SimMap.Tile.BUSH)
	assert_eq(m.get_tile(1, 1), SimMap.Tile.WATER)
	assert_eq(m.get_tile(0, 0), SimMap.Tile.FLOOR, "под точкой появления — пол")
	assert_eq(m.spawns[0], [Vector2(0.5, 0.5)])
	assert_eq(m.spawns[1], [Vector2(3.5, 1.5)])
	assert_eq(m.markers["G"], [Vector2(2.5, 1.5)])


func test_out_of_bounds_is_hard_wall() -> void:
	var m := SimFixtures.open_map(3, 3)
	assert_eq(m.get_tile(-1, 0), SimMap.Tile.HARD_WALL)
	assert_eq(m.get_tile(3, 0), SimMap.Tile.HARD_WALL)


func test_resolve_circle_pushes_out_of_wall() -> void:
	var m := SimMap.from_lines(PackedStringArray(["...", ".#.", "..."]))
	var p := m.resolve_circle(Vector2(1.2, 1.5), 0.4)
	assert_almost_eq(p.x, 0.6, 0.001)


func test_load_json(params: Variant = use_parameters(["res://data/maps/_debug_arena.json"])) -> void:
	var m := SimMap.load_json(params)
	assert_not_null(m)
	assert_true(m.spawns.has(0) and m.spawns.has(1), "есть точки обеих команд")
	assert_eq(m.meta.get("mode"), "deathmatch")
