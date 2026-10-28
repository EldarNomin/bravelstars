extends SceneTree
## Twenty deterministic 3v3 bot matches, balanced across all production maps.

const MATCHES: int = 20
const MODES: Array[StringName] = [&"teamfight", &"heist"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := ""
	var revision := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--revision="):
			revision = arg.trim_prefix("--revision=")
	if output.is_empty() or revision.is_empty():
		_fail("pass --output-dir and --revision")
		return
	var maps: Array[Dictionary] = []
	for mode in MODES:
		for path in MatchConfig.maps_for_mode(mode):
			maps.append({"mode": mode, "path": path})
	if maps.is_empty() or maps.size() > MATCHES:
		_fail("cannot cover every production map with 20 matches")
		return
	for mode in MODES:
		if MatchConfig.maps_for_mode(mode).is_empty():
			_fail("no production map for " + String(mode))
			return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create output directory")
		return
	for index in MATCHES:
		if FileAccess.file_exists(output.path_join("match_%02d.json" % (index + 1))):
			_fail("output already contains match journals; choose a new directory")
			return
	for index in MATCHES:
		if not _run_one(index, maps[index % maps.size()], output, revision):
			return
	print("MATCH_LOG_OK matches=", MATCHES, " maps=", maps.size())
	quit(0)


func _run_one(index: int, map_spec: Dictionary, output: String, revision: String) -> bool:
	var hero: StringName = MatchConfig.HEROES[index % MatchConfig.HEROES.size()]
	var config := MatchConfig.make(map_spec.mode, hero, map_spec.path)
	config.seed_value = index + 1
	config.difficulty = MatchConfig.Difficulty.NORMAL
	var setup := MatchSetup.create(config)
	setup.bots.add(setup.player, MatchSetup.tuned_profile(hero, config.difficulty), config.seed_value)
	var logger := MatchLogger.new()
	var world := setup.world
	var limit := world.mode.countdown_ticks + world.mode.duration_ticks + 1
	for _tick in limit:
		setup.step(null)
		logger.capture(world)
		if world.mode.is_finished():
			break
	if not world.mode.is_finished():
		_fail("match did not finish on " + config.map_path)
		return false
	var players: Array[Dictionary] = []
	for brawler in world.brawlers:
		players.append({"id": brawler.id, "hero": String(brawler.data.id), "team": brawler.team})
	var record := {
		"schema_version": 1, "revision": revision, "seed": config.seed_value,
		"mode": String(config.mode), "map": config.map_path, "map_name": world.map.map_name,
		"map_sha256": FileAccess.get_sha256(config.map_path), "tick_rate": SimConstants.TICK_RATE,
		"ticks": world.tick, "winner": world.mode.winner, "reason": world.mode.end_reason,
		"scores": logger._json_value(world.mode.scores), "players": players, "events": logger.events,
	}
	var path := output.path_join("match_%02d.json" % (index + 1))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write " + path)
		return false
	file.store_string(JSON.stringify(record) + "\n")
	file.close()
	print("MATCH_LOG ", path, " seed=", config.seed_value, " ticks=", world.tick)
	return true


func _fail(message: String) -> void:
	push_error("MATCH_LOG: " + message)
	quit(1)
