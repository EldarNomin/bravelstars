class_name SimMap
extends RefCounted
## Карта-сетка. Клетка (x, y) занимает квадрат [x, x+1) × [y, y+1); центр — (x+0.5, y+0.5).
## В 3D: координата сетки y соответствует оси Z.
##
## Формат — data/maps/*.json, описание в docs/map_format.md.

enum Tile { FLOOR, WALL, HARD_WALL, BUSH, WATER }

const CHAR_TO_TILE: Dictionary = {
	".": Tile.FLOOR,
	"#": Tile.WALL,
	"X": Tile.HARD_WALL,
	"*": Tile.BUSH,
	"~": Tile.WATER,
}

var map_name: String = ""
var width: int = 0
var height: int = 0
var tiles: PackedByteArray = PackedByteArray()
## Команда (0..8) -> Array[Vector2] точек появления. Символы '1'..'9'.
var spawns: Dictionary = {}
## Остальные буквы (например 'G' — шахта кристаллов) -> Array[Vector2]. Клетка под ними — пол.
var markers: Dictionary = {}
## Произвольные поля из JSON (режим, автор...).
var meta: Dictionary = {}


static func from_lines(lines: PackedStringArray, p_name: String = "") -> SimMap:
	var m := SimMap.new()
	m.map_name = p_name
	m.height = lines.size()
	for line in lines:
		m.width = maxi(m.width, line.length())
	m.tiles.resize(m.width * m.height)
	m.tiles.fill(Tile.FLOOR)
	for y in m.height:
		var line: String = lines[y]
		for x in line.length():
			var c := line[x]
			var center := Vector2(x + 0.5, y + 0.5)
			if CHAR_TO_TILE.has(c):
				m.tiles[y * m.width + x] = CHAR_TO_TILE[c]
			elif c >= "1" and c <= "9":
				var team := c.to_int() - 1
				if not m.spawns.has(team):
					m.spawns[team] = []
				m.spawns[team].append(center)
			else:
				if not m.markers.has(c):
					m.markers[c] = []
				m.markers[c].append(center)
	return m


static func load_json(path: String) -> SimMap:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SimMap: не удалось разобрать %s" % path)
		return null
	var d: Dictionary = parsed
	var grid := PackedStringArray(d.get("grid", []))
	var m := from_lines(grid, d.get("name", path.get_file().get_basename()))
	for key: String in d.keys():
		if key != "grid":
			m.meta[key] = d[key]
	return m


static func blocks_movement(t: int) -> bool:
	return t == Tile.WALL or t == Tile.HARD_WALL or t == Tile.WATER


static func blocks_projectiles(t: int) -> bool:
	return t == Tile.WALL or t == Tile.HARD_WALL


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Вне карты — непробиваемая стена.
func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.HARD_WALL
	return tiles[y * width + x]


func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[y * width + x] = t


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func tile_at(pos: Vector2) -> int:
	var c := cell_of(pos)
	return get_tile(c.x, c.y)


func is_bush_at(pos: Vector2) -> bool:
	return tile_at(pos) == Tile.BUSH


## Выталкивает круг из всех клеток, мешающих движению. Возвращает исправленную позицию.
func resolve_circle(pos: Vector2, radius: float) -> Vector2:
	var p := pos
	for _i in 3:
		var moved := false
		var x0 := floori(p.x - radius)
		var x1 := floori(p.x + radius)
		var y0 := floori(p.y - radius)
		var y1 := floori(p.y + radius)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if not blocks_movement(get_tile(x, y)):
					continue
				var closest := Vector2(clampf(p.x, x, x + 1), clampf(p.y, y, y + 1))
				var diff := p - closest
				var dist := diff.length()
				if dist >= radius:
					continue
				if dist > 0.0001:
					p += diff / dist * (radius - dist)
				else:
					p = _push_out_of_cell(p, x, y, radius)
				moved = true
		if not moved:
			break
	return p


func _push_out_of_cell(p: Vector2, x: int, y: int, radius: float) -> Vector2:
	var left := p.x - x
	var right := x + 1 - p.x
	var top := p.y - y
	var bottom := y + 1 - p.y
	var m := minf(minf(left, right), minf(top, bottom))
	if m == left:
		return Vector2(x - radius, p.y)
	if m == right:
		return Vector2(x + 1 + radius, p.y)
	if m == top:
		return Vector2(p.x, y - radius)
	return Vector2(p.x, y + 1 + radius)


func to_lines() -> PackedStringArray:
	var tile_to_char := {}
	for c: String in CHAR_TO_TILE.keys():
		tile_to_char[CHAR_TO_TILE[c]] = c
	var out := PackedStringArray()
	for y in height:
		var line := ""
		for x in width:
			line += tile_to_char[get_tile(x, y)]
		out.append(line)
	return out
