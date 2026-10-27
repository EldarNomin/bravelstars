extends GutTest

const ARENA: String = "res://data/maps/_debug_arena.json"


func _hero(id: String) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id)


func test_bot_hunts_down_stationary_enemy() -> void:
	var w := SimWorld.new(SimMap.load_json(ARENA), 3)
	var bot := w.add_brawler(_hero("lynx"), 0)
	var dummy := w.add_brawler(_hero("anvil"), 1, Vector2(19.5, 12.5))
	var bots := BotTeam.new(w)
	var brain := bots.add(bot)
	brain.profile.skill = 1.0
	for _i in SimConstants.ticks(45.0):
		bots.drive(w)
		w.step()
		if dummy.deaths > 0:
			break
	assert_eq(dummy.deaths, 1, "бот нашёл и убил неподвижную цель за 45 с")


func test_bot_does_not_shoot_hidden_enemy() -> void:
	var m := SimMap.from_lines(PackedStringArray([
		"..............",
		"..........***.",
		"..........***.",
	]))
	var w := SimWorld.new(m, 1)
	var bot := w.add_brawler(_hero("lynx"), 0, Vector2(2.5, 1.5))
	w.add_brawler(_hero("anvil"), 1, Vector2(11.5, 1.5))
	var bots := BotTeam.new(w)
	bots.add(bot)
	for _i in 15:
		var cmd := bots.brains[0].think(w)
		assert_false(cmd.attack, "враг в кусте не виден — не стреляет")
		w.set_input(bot.id, cmd)
		w.step()


func test_bot_retreats_when_low() -> void:
	var w := SimWorld.new(SimFixtures.open_map(30, 30), 1)
	var bot := w.add_brawler(_hero("lynx"), 0, Vector2(10.5, 15.5))
	w.add_brawler(_hero("anvil"), 1, Vector2(14.5, 15.5))
	bot.hp = 300
	bot.last_damage_tick = 0
	var bots := BotTeam.new(w)
	bots.add(bot)
	for _i in 30:
		bots.drive(w)
		w.step()
	assert_eq(bots.brains[0].state, BotBrain.State.RETREAT)
	assert_lt(bot.pos.x, 10.0, "отходит от угрозы")


func _bot_match(seed_value: int) -> SimWorld:
	var w := SimWorld.new(SimMap.load_json(ARENA), seed_value, load("res://data/balance/global.tres"))
	w.mode = TeamFight.new()
	var bots := BotTeam.new(w)
	var roster: Array[String] = ["lynx", "anvil", "shishka"]
	for team in 2:
		for id in roster:
			bots.add(w.add_brawler(_hero(id), team), null, seed_value)
	var limit := w.mode.countdown_ticks + w.mode.duration_ticks + 10
	for _i in limit:
		bots.drive(w)
		w.step()
		if w.mode.is_finished():
			break
	return w


func test_full_bot_match_finishes() -> void:
	var w := _bot_match(11)
	assert_true(w.mode.is_finished(), "матч 3v3 ботов доигран")
	var total: int = w.mode.scores[0] + w.mode.scores[1]
	gut.p("счёт %s, причина: %s, тиков: %d" % [w.mode.scores, w.mode.end_reason, w.tick])
	assert_gt(total, 3, "боты реально воюют")


func test_bot_match_deterministic() -> void:
	assert_eq(_bot_match(5).state_hash(), _bot_match(5).state_hash())
