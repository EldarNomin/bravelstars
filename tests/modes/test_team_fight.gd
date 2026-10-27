extends GutTest

var w: SimWorld
var red: SimBrawler
var blue: SimBrawler


func before_each() -> void:
	w = SimWorld.new(SimFixtures.open_map(), 1)
	w.mode = TeamFight.new(2, 10.0, 1.0)
	blue = w.add_brawler(SimFixtures.brawler(), 0, Vector2(5.5, 5.5))
	red = w.add_brawler(SimFixtures.brawler(), 1, Vector2(9.5, 5.5))


func _skip_countdown() -> void:
	SimFixtures.run(w, w.mode.countdown_ticks)


func test_countdown_blocks_input() -> void:
	SimFixtures.run(w, 10, blue, InputCommand.create(Vector2.RIGHT))
	assert_eq(blue.pos, Vector2(5.5, 5.5))
	assert_eq(w.mode.phase, GameMode.Phase.COUNTDOWN)
	_skip_countdown()
	assert_eq(w.mode.phase, GameMode.Phase.PLAYING)
	SimFixtures.run(w, 10, blue, InputCommand.create(Vector2.RIGHT))
	assert_gt(blue.pos.x, 5.5)


func test_kills_score_and_win() -> void:
	_skip_countdown()
	w.damage(red, 99999, blue, null, false, blue.pos)
	assert_eq(w.mode.scores[0], 1)
	assert_false(w.mode.is_finished())
	SimFixtures.run(w, w.secs(w.balance.respawn_time + w.balance.spawn_shield_time) + 1)
	w.damage(red, 99999, blue, null, false, blue.pos)
	assert_true(w.mode.is_finished())
	assert_eq(w.mode.winner, 0)
	assert_eq(w.mode.end_reason, "score")
	var types: Array = w.drain_events().map(func(e: Dictionary) -> StringName: return e["type"])
	assert_has(types, SimEvents.MATCH_START)
	assert_has(types, SimEvents.MATCH_END)


func test_no_score_during_countdown() -> void:
	w.damage(red, 99999, blue, null, false, blue.pos)
	assert_eq(w.mode.scores[0], 0)


func test_time_out_draw_and_leader() -> void:
	_skip_countdown()
	SimFixtures.run(w, w.mode.duration_ticks + 1)
	assert_true(w.mode.is_finished())
	assert_eq(w.mode.winner, -1, "0:0 — ничья")
	assert_eq(w.mode.end_reason, "time")


func test_input_frozen_after_finish() -> void:
	_skip_countdown()
	SimFixtures.run(w, w.mode.duration_ticks + 1)
	var p := blue.pos
	SimFixtures.run(w, 10, blue, InputCommand.create(Vector2.RIGHT))
	assert_eq(blue.pos, p)
