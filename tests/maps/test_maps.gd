extends GutTest
## C-17: все боевые карты в data/maps/ проходят MapValidator.
## Файлы с '_' в начале (отладочные) не проверяются.

const MAPS_DIR: String = "res://data/maps/"


func _map_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(MAPS_DIR):
		if f.ends_with(".json") and not f.begins_with("_"):
			out.append(MAPS_DIR + f)
	return out


func test_all_maps_valid() -> void:
	var files := _map_files()
	if files.is_empty():
		pass_test("боевых карт пока нет")
		return
	for path in files:
		var m := SimMap.load_json(path)
		assert_not_null(m, path)
		if m == null:
			continue
		var errs := MapValidator.validate(m)
		assert_eq(errs.size(), 0, "%s:\n  %s" % [path, "\n  ".join(errs)])
		assert_true(m.meta.has("name") and m.meta.has("mode"), "%s: есть name и mode" % path)


func test_bots_can_play_every_map() -> void:
	for path in _map_files():
		var w := SimWorld.new(SimMap.load_json(path), 1)
		w.mode = TeamFight.new(3, 60.0)
		var bots := BotTeam.new(w)
		for team in 2:
			for id in ["lynx", "anvil", "shishka"]:
				bots.add(w.add_brawler(load("res://data/brawlers/%s.tres" % id), team))
		for _i in w.mode.countdown_ticks + w.mode.duration_ticks + 5:
			bots.drive(w)
			w.step()
			if w.mode.is_finished():
				break
		var kills: int = w.mode.scores[0] + w.mode.scores[1]
		assert_gt(kills, 0, "%s: боты находят друг друга и воюют (за минуту %d убийств)" % [path, kills])


# --- проверка самого валидатора ------------------------------------------------


func _good() -> PackedStringArray:
	return PackedStringArray([
		"XXXXXXXXXXX",
		"X1..#....2X",
		"X.**#.#**.X",
		"X1**#.#**2X",
		"X.**#.#**.X",
		"X1....#..2X",
		"XXXXXXXXXXX",
	])


func test_validator_accepts_good_map() -> void:
	assert_eq(MapValidator.validate(SimMap.from_lines(_good())).size(), 0)


func test_validator_catches_problems() -> void:
	var g := _good()
	var cases := {
		"край": _patch(g, 3, "X1**#.#**2."),
		"симметр": _patch(g, 5, "X1.......2X"),
		"одиночный куст": _patch(_patch(_patch(g, 2, "X.*.#.#.*.X"), 3, "X1..#.#..2X"), 4, "X.*.#.#.*.X"),
		"простреливают": _patch(_patch(g, 1, "X1.......2X"), 5, "X1.......2X"),
		"карман": _patch(_patch(g, 2, "X.**#X#**.X"), 4, "X.**#X#**.X"),
	}
	for expected: String in cases.keys():
		var errs := MapValidator.validate(SimMap.from_lines(PackedStringArray(cases[expected])))
		var joined := "\n".join(errs)
		assert_string_contains(joined, expected, "ожидалась ошибка «%s», получено:\n%s" % [expected, joined])


func _patch(lines: PackedStringArray, row: int, text: String) -> PackedStringArray:
	var out := lines.duplicate()
	out[row] = text
	return out
