class_name MatchConfig
extends Resource
## Что за матч запускать: карта, режим, герой игрока, сложность ботов.
## Меню заполняет конфиг и кладёт в Game.next_match, сцена матча вызывает MatchSetup.create(config).

enum Difficulty { EASY, NORMAL, HARD }

const MODES: Array[StringName] = [&"teamfight", &"heist"]
const HEROES: Array[StringName] = [&"lynx", &"anvil", &"shishka"]
const MAPS_DIR: String = "res://data/maps/"
const BALANCE_PATH: String = "res://data/balance/global.tres"

@export var mode: StringName = &"teamfight"
## Пусто — первая подходящая карта для режима.
@export var map_path: String = ""
@export var hero_id: StringName = &"lynx"
@export var difficulty: Difficulty = Difficulty.NORMAL
## 0 — случайный seed при запуске.
@export var seed_value: int = 0
@export var team_size: int = 3


static func make(p_mode: StringName, p_hero: StringName = &"lynx", p_map: String = "") -> MatchConfig:
	var c := MatchConfig.new()
	c.mode = p_mode
	c.hero_id = p_hero
	c.map_path = p_map
	return c


## Боевые карты для режима (файлы с '_' в начале — отладочные, не показываются).
static func maps_for_mode(p_mode: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	var files := DirAccess.get_files_at(MAPS_DIR)
	files.sort()
	for f in files:
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var m := SimMap.load_json(MAPS_DIR + f)
		if m != null and StringName(m.meta.get("mode", "")) == p_mode:
			out.append(MAPS_DIR + f)
	return out


func resolved_map_path() -> String:
	if not map_path.is_empty():
		return map_path
	var maps := maps_for_mode(mode)
	if not maps.is_empty():
		return maps[0]
	return MAPS_DIR + ("_debug_heist.json" if mode == &"heist" else "_debug_arena.json")
