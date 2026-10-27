class_name BotNav
extends RefCounted
## Поиск пути по сетке карты для ботов. Один экземпляр на мир, перестраивается при изменении карты.

var _astar: AStarGrid2D = AStarGrid2D.new()
var _map: SimMap
var _version: int = -1


func _init(map: SimMap) -> void:
	_map = map
	_astar.region = Rect2i(0, 0, map.width, map.height)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	refresh()


func refresh() -> void:
	if _version == _map.version:
		return
	_version = _map.version
	for y in _map.height:
		for x in _map.width:
			_astar.set_point_solid(Vector2i(x, y), SimMap.blocks_movement(_map.get_tile(x, y)))


## Путь из центров клеток от from до to (без стартовой клетки). Пустой — пути нет.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	refresh()
	var a := _clamp_cell(_map.cell_of(from))
	var b := _nearest_open(_clamp_cell(_map.cell_of(to)))
	if _astar.is_point_solid(a) or b == Vector2i(-1, -1):
		return PackedVector2Array()
	var ids := _astar.get_id_path(a, b, true)
	var out := PackedVector2Array()
	for i in range(1, ids.size()):
		out.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
	return out


func is_walkable(cell: Vector2i) -> bool:
	refresh()
	return _map.in_bounds(cell.x, cell.y) and not _astar.is_point_solid(cell)


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, _map.width - 1), clampi(c.y, 0, _map.height - 1))


func _nearest_open(c: Vector2i) -> Vector2i:
	if not _astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _map.in_bounds(n.x, n.y) and not _astar.is_point_solid(n):
					return n
	return Vector2i(-1, -1)
