extends GutTest

var w: SimWorld
var mode: Heist
var me: SimBrawler
var foe: SimBrawler


func before_each() -> void:
	var m := SimMap.from_lines(PackedStringArray([
		"XXXXXXXXXXXXXXX",
		"X1...........2X",
		"XA.....G.....BX",
		"X1...........2X",
		"XXXXXXXXXXXXXXX",
	]))
	w = SimWorld.new(m, 1)
	mode = Heist.new(3, 60.0, 0.5)
	w.mode = mode
	mode.setup(w)
	me = w.add_brawler(SimFixtures.brawler(), 0)
	foe = w.add_brawler(SimFixtures.brawler(), 1)
	SimFixtures.run(w, mode.countdown_ticks + 1)


func test_markers_parsed() -> void:
	assert_eq(mode.mine, Vector2(7.5, 2.5))
	assert_eq(mode.safes[0], Vector2(1.5, 2.5))
	assert_eq(mode.safes[1], Vector2(13.5, 2.5))


func test_shard_spawns_and_is_picked_up() -> void:
	assert_eq(mode.shards.size(), 1, "первый осколок сразу после отсчёта")
	me.pos = mode.shards[0]
	w.step()
	assert_eq(Heist.carried(me), 1)
	assert_eq(mode.shards.size(), 0)


func test_carrier_slow_and_visible() -> void:
	me.pos = mode.shards[0]
	w.step()
	assert_almost_eq(me.speed_mult, Heist.CARRIER_SLOWDOWN, 0.001)
	assert_true(me.force_visible)
	w.map.set_tile(7, 3, SimMap.Tile.BUSH)
	me.pos = Vector2(7.5, 3.5)
	assert_true(w.is_visible_to(1, me), "с добычей виден даже в кусте")


func test_deposit_scores_and_wins() -> void:
	me.mode_data["shards"] = 2
	me.pos = mode.safes[0]
	w.step()
	assert_eq(mode.scores[0], 2)
	assert_eq(Heist.carried(me), 0)
	assert_eq(me.speed_mult, 1.0)
	me.mode_data["shards"] = 1
	w.step()
	assert_true(mode.is_finished())
	assert_eq(mode.winner, 0)


func test_no_deposit_in_enemy_safe() -> void:
	me.mode_data["shards"] = 2
	me.pos = mode.safes[1]
	w.step()
	assert_eq(mode.scores[0], 0)


func test_death_drops_everything() -> void:
	me.mode_data["shards"] = 3
	var before := mode.shards.size()
	w.damage(me, 99999, foe, null, false, foe.pos)
	assert_eq(Heist.carried(me), 0)
	assert_eq(mode.shards.size(), before + 3)


func test_bots_play_heist() -> void:
	var bw := SimWorld.new(SimMap.load_json("res://data/maps/_debug_heist.json"), 4)
	var h := Heist.new()
	bw.mode = h
	h.setup(bw)
	var bots := BotTeam.new(bw)
	for team in 2:
		for id in ["lynx", "anvil", "shishka"]:
			bots.add(bw.add_brawler(load("res://data/brawlers/%s.tres" % id), team))
	var deposits := 0
	for _i in h.countdown_ticks + h.duration_ticks + 5:
		bots.drive(bw)
		bw.step()
		for e in bw.drain_events():
			if e["type"] == SimEvents.DEPOSIT:
				deposits += 1
		if h.is_finished():
			break
	gut.p("Добыча, боты: счёт %s, сдач %d, причина %s" % [h.scores, deposits, h.end_reason])
	assert_true(h.is_finished())
	assert_gt(deposits, 2, "боты носят осколки в сейф")
