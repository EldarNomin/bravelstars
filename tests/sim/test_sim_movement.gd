extends GutTest


func test_moves_at_speed() -> void:
	var w := SimWorld.new(SimFixtures.open_map())
	var b := w.add_brawler(SimFixtures.brawler(), 0, Vector2(5, 5))
	SimFixtures.run(w, SimConstants.TICK_RATE, b, InputCommand.create(Vector2.RIGHT))
	assert_almost_eq(b.pos.x, 8.0, 0.01, "3 клетки/с за 1 секунду")
	assert_eq(b.facing, Vector2.RIGHT)


func test_diagonal_not_faster() -> void:
	var w := SimWorld.new(SimFixtures.open_map())
	var b := w.add_brawler(SimFixtures.brawler(), 0, Vector2(5, 5))
	SimFixtures.run(w, SimConstants.TICK_RATE, b, InputCommand.create(Vector2(1, 1)))
	assert_almost_eq(b.pos.distance_to(Vector2(5, 5)), 3.0, 0.01)


func test_walls_and_water_block() -> void:
	for wall in ["#", "X", "~"]:
		var m := SimMap.from_lines(PackedStringArray(["...." + wall + "...."]))
		var w := SimWorld.new(m)
		var b := w.add_brawler(SimFixtures.brawler(), 0, Vector2(1.5, 0.5))
		SimFixtures.run(w, 60, b, InputCommand.create(Vector2.RIGHT))
		assert_almost_eq(b.pos.x, 4.0 - b.data.radius, 0.01, "стоит перед '%s'" % wall)


func test_bush_does_not_block() -> void:
	var w := SimWorld.new(SimMap.from_lines(PackedStringArray(["...***...."])))
	var b := w.add_brawler(SimFixtures.brawler(), 0, Vector2(1.5, 0.5))
	SimFixtures.run(w, 60, b, InputCommand.create(Vector2.RIGHT))
	assert_gt(b.pos.x, 7.0)


func test_spawn_points_used_in_order() -> void:
	var w := SimWorld.new(SimMap.from_lines(PackedStringArray(["1.1...2"])))
	var a := w.add_brawler(SimFixtures.brawler(), 0)
	var b := w.add_brawler(SimFixtures.brawler(), 0)
	var c := w.add_brawler(SimFixtures.brawler(), 1)
	assert_eq(a.pos, Vector2(0.5, 0.5))
	assert_eq(b.pos, Vector2(2.5, 0.5))
	assert_eq(c.pos, Vector2(6.5, 0.5))


func test_stun_blocks_movement() -> void:
	var w := SimWorld.new(SimFixtures.open_map())
	var b := w.add_brawler(SimFixtures.brawler(), 0, Vector2(5, 5))
	b.stun_ticks = 10
	SimFixtures.run(w, 10, b, InputCommand.create(Vector2.RIGHT))
	assert_eq(b.pos, Vector2(5, 5))


func test_odd_team_takes_spawns_mirrored() -> void:
	var w := SimWorld.new(SimMap.from_lines(PackedStringArray(["1...2", "1...2", "1...2"])))
	var a := w.add_brawler(SimFixtures.brawler(), 0)
	var b := w.add_brawler(SimFixtures.brawler(), 1)
	assert_eq(a.pos, Vector2(0.5, 0.5), "команда 1 — сверху вниз")
	assert_eq(b.pos, Vector2(4.5, 2.5), "команда 2 — снизу вверх (зеркально при повороте на 180°)")
