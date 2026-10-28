extends SceneTree
## B-01: балансный прогон — дуэли 1v1 и матчи 3v3 ботов, CSV на выход.
## Запуск: godot --headless -s tools/balance/run_matches.gd -- \
##   --duels 100 --matches 30 --out docs/balance/results.csv
## Аргументы: --duels N (дуэлей на пару героев и карту, 100), --matches N (матчей 3v3 на режим и карту, 30),
## --out путь.csv (иначе CSV в stdout). Seeds фиксированы формулой — прогон повторяем.

const BALANCE := preload("res://data/balance/global.tres")
const HEROES: Array[String] = ["lynx", "anvil", "shishka"]
const DUEL_MAPS: Array[String] = ["_debug_arena", "sawmill", "canyon"]
const TEAM_MAPS: Array[String] = ["sawmill", "canyon", "clearing", "placer"]
const MAP_PATH: String = "res://data/maps/%s.json"
const ROSTER: Array[String] = ["lynx", "anvil", "shishka"]
const DUEL_CAP_SEC: float = 45.0

var args: Dictionary = {}
var rows: PackedStringArray = PackedStringArray()


func _init() -> void:
	_parse_args()
	_header()
	for map_name: String in DUEL_MAPS:
		for pi in HEROES.size():
			for pj in range(pi, HEROES.size()):
				_run_duels(HEROES[pi], HEROES[pj], map_name)
	for mode_name: String in ["teamfight", "heist"]:
		for map_name: String in TEAM_MAPS:
			_run_team_matches(mode_name, map_name)
	_write_out()
	quit()


func _parse_args() -> void:
	var user_args := OS.get_cmdline_user_args()
	var i := 0
	while i < user_args.size():
		var a: String = user_args[i]
		if a == "--duels" or a == "--matches":
			args[a.substr(2)] = int(user_args[i + 1])
			i += 2
		elif a == "--out":
			args["out"] = user_args[i + 1]
			i += 2
		else:
			i += 1


func _header() -> void:
	rows.append("kind,map,mode,hero1,hero2,seed,winner,ttk_sec,duration_sec,"
		+ "shots1,shots2,hits1,hits2,supers1,supers2,score1,score2,deposits1,deposits2,swap")


func _duel_seed(a: String, b: String, map_name: String, i: int) -> int:
	return (HEROES.find(a) + 1) * 100000 + (HEROES.find(b) + 1) * 10000 \
		+ (DUEL_MAPS.find(map_name) + 1) * 1000 + i


func _run_duels(hero_a: String, hero_b: String, map_name: String) -> void:
	var n: int = args.get("duels", 100)
	for i in n:
		var swapped := i >= n / 2
		var first := hero_b if swapped else hero_a
		var second := hero_a if swapped else hero_b
		var seed_v := _duel_seed(hero_a, hero_b, map_name, i)
		var w := SimWorld.new(SimMap.load_json(MAP_PATH % map_name), seed_v, BALANCE)
		w.mode = TeamFight.new(1, DUEL_CAP_SEC)
		var spawns: Dictionary = w.map.spawns
		w.add_brawler(_hero(first), 0, (spawns[0][0] as Vector2))
		w.add_brawler(_hero(second), 1, (spawns[1][0] as Vector2))
		var bots := BotTeam.new(w)
		bots.add(w.brawlers[0], null, seed_v)
		bots.add(w.brawlers[1], null, seed_v + 1)
		var st := _Counters.new()
		var limit: int = w.mode.countdown_ticks + w.mode.duration_ticks + 10
		for _tick in limit:
			bots.drive(w)
			w.step()
			_accumulate(w, st)
			if w.mode.is_finished():
				break
		var ttk := ""
		if not st.death_ticks.is_empty():
			ttk = "%.2f" % (float(st.death_ticks[0] - w.mode.countdown_ticks) / SimConstants.TICK_RATE)
		var cells: Array[String] = ["duel", map_name, "", hero_a, hero_b, str(seed_v),
			str(w.mode.winner), ttk, str(_duration_sec(w)),
			str(st.shots[0]), str(st.shots[1]), str(st.hits[0]), str(st.hits[1]),
			str(st.supers[0]), str(st.supers[1]), "", "", "", "", str(1 if swapped else 0)]
		assert(cells.size() == 20)
		rows.append(",".join(cells))


func _run_team_matches(mode_name: String, map_name: String) -> void:
	var n: int = args.get("matches", 30)
	for i in n:
		var seed_v: int = 500000 + (0 if mode_name == "teamfight" else 1) * 100000 \
			+ (TEAM_MAPS.find(map_name) + 1) * 1000 + i
		var w := SimWorld.new(SimMap.load_json(MAP_PATH % map_name), seed_v, BALANCE)
		w.mode = Heist.new() if mode_name == "heist" else TeamFight.new()
		if mode_name == "heist":
			w.mode.setup(w)
		var bots := BotTeam.new(w)
		for team in 2:
			for id: String in ROSTER:
				bots.add(w.add_brawler(_hero(id), team), null, seed_v + team * 10 + ROSTER.find(id))
		var st := _Counters.new()
		var limit: int = w.mode.countdown_ticks + w.mode.duration_ticks + 10
		for _tick in limit:
			bots.drive(w)
			w.step()
			_accumulate(w, st)
			if w.mode.is_finished():
				break
		var cells: Array[String] = ["team", map_name, mode_name, "mixed", "", str(seed_v),
			str(w.mode.winner), "", str(_duration_sec(w)),
			str(st.shots[0]), str(st.shots[1]), str(st.hits[0]), str(st.hits[1]),
			str(st.supers[0]), str(st.supers[1]),
			str(int(w.mode.scores[0])), str(int(w.mode.scores[1])),
			str(st.deposits[0] if mode_name == "heist" else 0),
			str(st.deposits[1] if mode_name == "heist" else 0)]
		assert(cells.size() == 19)
		rows.append(",".join(cells))


## Счётчики матча: выстрелы/попадания/суперы по командам, тики смертей, сдачи.
class _Counters:
	var shots := [0, 0]
	var hits := [0, 0]
	var supers := [0, 0]
	var deposits := [0, 0]
	var death_ticks: Array[int] = []

	func team_of(world: SimWorld, brawler_id: int) -> int:
		var b := world.get_brawler(brawler_id)
		return b.team if b != null else 0


func _accumulate(w: SimWorld, st: _Counters) -> void:
	for ev: Dictionary in w.drain_events():
		match ev["type"]:
			SimEvents.ATTACK:
				var team := st.team_of(w, int(ev["brawler"]))
				if bool(ev.get("super", false)):
					st.supers[team] += 1
				else:
					st.shots[team] += 1
			SimEvents.HIT:
				if ev.get("source", 0) != 0:
					st.hits[st.team_of(w, int(ev["source"]))] += 1
			SimEvents.DEATH:
				st.death_ticks.append(int(ev["tick"]))
			SimEvents.DEPOSIT:
				st.deposits[int(ev["team"])] += 1


func _duration_sec(w: SimWorld) -> int:
	return int(round(float(w.tick) / SimConstants.TICK_RATE))


func _hero(id: String) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id)


func _write_out() -> void:
	printerr("строк CSV: %d" % (rows.size() - 1))
	var out: String = args.get("out", "")
	if out.is_empty():
		print("\n".join(rows))
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("не удалось открыть %s" % out)
		print("\n".join(rows))
		return
	f.store_string("\n".join(rows) + "\n")
	f.close()
	printerr("CSV записан: %s" % out)
