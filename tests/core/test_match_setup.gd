extends GutTest


func test_teamfight_setup_has_6_brawlers_and_5_bots() -> void:
	var c := MatchConfig.make(&"teamfight", &"anvil")
	c.seed_value = 7
	var s := MatchSetup.create(c)
	assert_eq(s.world.brawlers.size(), 6)
	assert_eq(s.bots.brains.size(), 5)
	assert_eq(String(s.player.data.id), "anvil")
	assert_eq(s.player.team, 0)
	assert_true(s.world.mode is TeamFight)
	var ally_ids: Array = []
	for b in s.world.brawlers:
		if b.team == 0 and b != s.player:
			ally_ids.append(String(b.data.id))
	assert_does_not_have(ally_ids, "anvil", "союзники — другие герои")


func test_heist_setup_uses_heist_map() -> void:
	var c := MatchConfig.make(&"heist")
	c.seed_value = 3
	var s := MatchSetup.create(c)
	assert_true(s.world.mode is Heist)
	assert_ne((s.world.mode as Heist).mine, Vector2.INF)
	assert_true(s.world.map.markers.has("G"))


func test_maps_for_mode_filters_by_meta() -> void:
	for path in MatchConfig.maps_for_mode(&"teamfight"):
		assert_false(path.get_file().begins_with("_"))
		assert_eq(SimMap.load_json(path).meta.get("mode"), "teamfight")
	assert_true(MatchConfig.maps_for_mode(&"teamfight").size() >= 2, "Лесопилка и Каньон")


func test_difficulty_scales_bots_without_touching_shared_profile() -> void:
	var shared_skill := BotRoles.profile_for(&"lynx").skill
	var easy := MatchSetup.tuned_profile(&"lynx", MatchConfig.Difficulty.EASY)
	var hard := MatchSetup.tuned_profile(&"lynx", MatchConfig.Difficulty.HARD)
	assert_lt(easy.skill, shared_skill)
	assert_gt(easy.reaction_ticks, hard.reaction_ticks)
	assert_eq(BotRoles.profile_for(&"lynx").skill, shared_skill, "общий профиль не изменился")


func test_hard_bots_beat_easy_bots() -> void:
	var score := {"easy": 0, "hard": 0}
	for seed_value in [21, 22, 23, 24]:
		var w := SimWorld.new(SimMap.load_json("res://data/maps/sawmill.json"), seed_value)
		w.mode = TeamFight.new()
		var bots := BotTeam.new(w)
		for team in 2:
			var diff := MatchConfig.Difficulty.EASY if team == 0 else MatchConfig.Difficulty.HARD
			for id in MatchConfig.HEROES:
				bots.add(w.add_brawler(MatchSetup.hero(id), team), MatchSetup.tuned_profile(id, diff), seed_value)
		for _i in w.mode.countdown_ticks + w.mode.duration_ticks + 5:
			bots.drive(w)
			w.step()
			if w.mode.is_finished():
				break
		score["easy"] += w.mode.scores[0]
		score["hard"] += w.mode.scores[1]
	gut.p("лёгкие vs сложные, убийства за 4 матча: %s" % score)
	assert_gt(score["hard"], score["easy"], "сложные боты сильнее лёгких")


func test_step_advances_match() -> void:
	var c := MatchConfig.make(&"teamfight")
	c.seed_value = 5
	var s := MatchSetup.create(c)
	for _i in s.world.mode.countdown_ticks + 2:
		s.step(InputCommand.create(Vector2.RIGHT))
	assert_eq(s.world.mode.phase, GameMode.Phase.PLAYING)
	assert_gt(s.player.pos.x, s.player.spawn_pos.x)
