class_name MapValidator
extends RefCounted
## Проверка карт по правилам docs/map_format.md. Возвращает список ошибок (пусто — карта годная).

## Сколько точек появления на команду в режиме боя команд.
const SPAWNS_PER_TEAM: int = 3


static func validate(m: SimMap) -> PackedStringArray:
	var errs := PackedStringArray(m.errors)
	if m.width < 5 or m.height < 5:
		errs.append("карта меньше 5×5")
		return errs
	_check_edges(m, errs)
	_check_spawns(m, errs)
	_check_symmetry(m, errs)
	_check_bushes(m, errs)
	_check_reachability(m, errs)
	_check_spawn_lanes(m, errs)
	if m.meta.get("mode") == "heist":
		_check_heist(m, errs)
	return errs


## «Добыча»: одна шахта 'G' в центре симметрии, сейфы 'A' (команда 1) и 'B' (команда 2) зеркальны.
static func _check_heist(m: SimMap, errs: PackedStringArray) -> void:
	var g: Array = m.markers.get("G", [])
	var a: Array = m.markers.get("A", [])
	var b: Array = m.markers.get("B", [])
	if g.size() != 1 or a.size() != 1 or b.size() != 1:
		errs.append("Добыча: нужно ровно по одной метке G, A, B")
		return
	var center := Vector2(m.width, m.height) * 0.5
	if (g[0] as Vector2).distance_to(center) > 0.01:
		errs.append("Добыча: шахта G не в центре карты")
	if (a[0] as Vector2) != Vector2(m.width, m.height) - (b[0] as Vector2):
		errs.append("Добыча: сейфы A и B не зеркальны")


static func _check_edges(m: SimMap, errs: PackedStringArray) -> void:
	for x in m.width:
		for y in [0, m.height - 1]:
			if m.get_tile(x, y) != SimMap.Tile.HARD_WALL:
				errs.append("край (%d, %d) не 'X'" % [x, y])
	for y in m.height:
		for x in [0, m.width - 1]:
			if m.get_tile(x, y) != SimMap.Tile.HARD_WALL:
				errs.append("край (%d, %d) не 'X'" % [x, y])


static func _check_spawns(m: SimMap, errs: PackedStringArray) -> void:
	for team in [0, 1]:
		var n: int = m.spawns.get(team, []).size()
		if n != SPAWNS_PER_TEAM:
			errs.append("у команды %d точек появления %d, нужно %d" % [team + 1, n, SPAWNS_PER_TEAM])


## Поворот на 180°: клетка (x, y) == клетка (w-1-x, h-1-y), точки команд меняются местами.
static func _check_symmetry(m: SimMap, errs: PackedStringArray) -> void:
	var bad := 0
	for y in m.height:
		for x in m.width:
			if m.get_tile(x, y) != m.get_tile(m.width - 1 - x, m.height - 1 - y):
				bad += 1
	if bad > 0:
		errs.append("нет симметрии поворотом на 180°: %d клеток" % bad)
	var a: Array = m.spawns.get(0, [])
	var b: Array = m.spawns.get(1, [])
	for p: Vector2 in a:
		var mirror := Vector2(m.width, m.height) - p
		if not b.has(mirror):
			errs.append("точке команды 1 %s нет зеркальной у команды 2" % p)


## Каждый куст должен входить хотя бы в один квадрат 2×2 из кустов.
static func _check_bushes(m: SimMap, errs: PackedStringArray) -> void:
	for y in m.height:
		for x in m.width:
			if m.get_tile(x, y) != SimMap.Tile.BUSH:
				continue
			var ok := false
			for dy in [-1, 0]:
				for dx in [-1, 0]:
					if _is_bush_square(m, x + dx, y + dy):
						ok = true
			if not ok:
				errs.append("одиночный куст (%d, %d): кусты — группами от 2×2" % [x, y])


static func _is_bush_square(m: SimMap, x: int, y: int) -> bool:
	for dy in 2:
		for dx in 2:
			if m.get_tile(x + dx, y + dy) != SimMap.Tile.BUSH:
				return false
	return true


## Все проходимые клетки связаны (нет запертых карманов), все точки появления достижимы.
static func _check_reachability(m: SimMap, errs: PackedStringArray) -> void:
	var start := Vector2i(-1, -1)
	var walkable := 0
	for y in m.height:
		for x in m.width:
			if not SimMap.blocks_movement(m.get_tile(x, y)):
				walkable += 1
				if start.x < 0:
					start = Vector2i(x, y)
	if start.x < 0:
		errs.append("нет проходимых клеток")
		return
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and m.in_bounds(n.x, n.y) and not SimMap.blocks_movement(m.get_tile(n.x, n.y)):
				seen[n] = true
				queue.append(n)
	if seen.size() != walkable:
		errs.append("недостижимых проходимых клеток: %d (запертые карманы)" % (walkable - seen.size()))


## С точки появления не простреливается вражеская точка появления.
static func _check_spawn_lanes(m: SimMap, errs: PackedStringArray) -> void:
	for p: Vector2 in m.spawns.get(0, []):
		for q: Vector2 in m.spawns.get(1, []):
			if m.has_line_of_fire(p, q, 0.3):
				errs.append("точки появления %s и %s простреливают друг друга" % [p, q])
