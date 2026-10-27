extends GutTest
## C-10b: характер ботов по ролям. Профили берутся через BotTeam.add без явного профиля
## (то есть ровно тот путь, что будет в матче).

const ARENA: String = "res://data/maps/_debug_arena.json"
const MATCHES: int = 10
const SAMPLE_EVERY: int = 15
const ROSTER: Array[StringName] = [&"lynx", &"anvil", &"shishka"]


func _hero(id: StringName) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id)


func test_profile_for_gives_each_hero_its_own_profile() -> void:
	var profiles: Array[BotProfile] = []
	for id in ROSTER:
		var p := BotRoles.profile_for(id)
		assert_not_null(p, "у героя %s есть профиль" % id)
		assert_false(profiles.has(p), "у %s свой профиль, не общий с другими" % id)
		profiles.append(p)
	assert_null(BotRoles.profile_for(&"unknown"), "неизвестный id -> профиль по умолчанию")
	var lynx := BotRoles.profile_for(&"lynx")
	assert_between(lynx.preferred_range, 0.85, 0.9, "Рысь держит дальнюю дистанцию")
	assert_gt(lynx.retreat_hp, 0.4, "Рысь рано отступает")
	var anvil := BotRoles.profile_for(&"anvil")
	assert_between(anvil.preferred_range, 0.3, 0.4, "Наковальня лезет вплотную")
	assert_lt(anvil.retreat_hp, 0.2, "Наковальня почти не отступает")
	assert_gt(anvil.bush_preference, 0.7, "Наковальня любит кусты")


## Один матч ботов 3v3. Возвращает дистанции до ближайшего видимого врага в бою
## (состояние FIGHT; сумма/число замеров по героям), убийства и смерти по героям.
func _run_match(seed_value: int) -> Dictionary:
	var w := SimWorld.new(SimMap.load_json(ARENA), seed_value, load("res://data/balance/global.tres"))
	w.mode = TeamFight.new()
	var bots := BotTeam.new(w)
	for team in 2:
		for id in ROSTER:
			bots.add(w.add_brawler(_hero(id), team))
	var dist_sum: Dictionary = {}
	var dist_n: Dictionary = {}
	var limit := w.mode.countdown_ticks + w.mode.duration_ticks + 10
	for _i in limit:
		bots.drive(w)
		w.step()
		if w.mode.is_finished():
			break
		if w.tick > w.mode.countdown_ticks and w.tick % SAMPLE_EVERY == 0:
			_sample_distance(w, bots.brains, dist_sum, dist_n)
	var kills: Dictionary = {}
	var deaths: Dictionary = {}
	for b in w.brawlers:
		var key := String(b.data.id)
		kills[key] = kills.get(key, 0) + b.kills
		deaths[key] = deaths.get(key, 0) + b.deaths
	return {
		"finished": w.mode.is_finished(),
		"kills_total": int(w.mode.scores[0]) + int(w.mode.scores[1]),
		"dist_sum": dist_sum,
		"dist_n": dist_n,
		"kills": kills,
		"deaths": deaths,
	}


func _sample_distance(w: SimWorld, brains: Array, sums: Dictionary, counts: Dictionary) -> void:
	for brain: BotBrain in brains:
		if brain.state != BotBrain.State.FIGHT:
			continue
		var b := w.get_brawler(brain.brawler_id)
		if b == null or not b.alive:
			continue
		var best := INF
		for e in w.enemies_of(b):
			if e.alive and w.is_visible_to(b.team, e):
				best = minf(best, b.pos.distance_to(e.pos))
		if best < INF:
			var key := String(b.data.id)
			sums[key] = sums.get(key, 0.0) + best
			counts[key] = counts.get(key, 0) + 1


func test_lynx_keeps_more_distance_than_anvil_over_10_matches() -> void:
	var dist_sum: Dictionary = {}
	var dist_n: Dictionary = {}
	var kills: Dictionary = {}
	var deaths: Dictionary = {}
	for seed_value in range(1, MATCHES + 1):
		var m: Dictionary = _run_match(seed_value)
		assert_true(m.finished, "матч с seed %d доигран" % seed_value)
		assert_gt(m.kills_total, 0, "в матче с seed %d есть убийства" % seed_value)
		for key: String in (m.dist_sum as Dictionary).keys():
			dist_sum[key] = dist_sum.get(key, 0.0) + m.dist_sum[key]
			dist_n[key] = dist_n.get(key, 0) + m.dist_n[key]
			kills[key] = kills.get(key, 0) + m.kills[key]
			deaths[key] = deaths.get(key, 0) + m.deaths[key]
	var avg := func(key: String) -> float:
		return dist_sum.get(key, 0.0) / maxi(dist_n.get(key, 1), 1)
	var lines: PackedStringArray = []
	for id in ROSTER:
		var key := String(id)
		lines.append("%s: дистанция %.2f, убийств %d, смертей %d" % [
			key, avg.call(key), kills.get(key, 0), deaths.get(key, 0)])
	gut.p("10 матчей, " + ", ".join(lines))
	assert_gt(
		avg.call("lynx"),
		avg.call("anvil"),
		"Рысь держится от видимых врагов дальше, чем Наковальня")
