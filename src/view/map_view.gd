class_name MapView
extends Node3D
## Отрисовка карты на основе low-poly моделей окружения от Codex (assets/models/env/*.glb).
## Для высокой производительности на мобильных устройствах использует MultiMeshInstance3D.
## Обрабатывает разрушение стен (с вылетом обломков) и отрастание кустов.

const MODEL_FLOOR: String = "res://assets/models/env/floor.glb"
const MODEL_WALL: String = "res://assets/models/env/wall.glb"
const MODEL_HARD_WALL: String = "res://assets/models/env/hard_wall.glb"
const MODEL_BUSH_1: String = "res://assets/models/env/bush_01.glb"
const MODEL_BUSH_2: String = "res://assets/models/env/bush_02.glb"
const MODEL_WATER: String = "res://assets/models/env/water.glb"

const DEBRIS_PATHS: Array[String] = [
	"res://assets/models/env/debris_01.glb",
	"res://assets/models/env/debris_02.glb",
	"res://assets/models/env/debris_03.glb",
	"res://assets/models/env/debris_04.glb",
]

var _floor_mm: MultiMeshInstance3D
var _hard_wall_mm: MultiMeshInstance3D
var _wall_mm: MultiMeshInstance3D
var _bush_mm: MultiMeshInstance3D
var _water_mm: MultiMeshInstance3D

var _wall_indices: Dictionary = {}
var _bush_indices: Dictionary = {}

var _debris_scenes: Array[PackedScene] = []


func build_map(map: SimMap) -> void:
	_load_debris_scenes()

	var floor_transforms: Array[Transform3D] = []
	var hard_wall_transforms: Array[Transform3D] = []
	var wall_transforms: Array[Transform3D] = []
	var bush_transforms: Array[Transform3D] = []
	var water_transforms: Array[Transform3D] = []

	_wall_indices.clear()
	_bush_indices.clear()

	for y in map.height:
		for x in map.width:
			var center := Vector3(x + 0.5, 0.0, y + 0.5)
			var t := map.get_tile(x, y)

			# Пол укладывается подо всей игровой картой
			floor_transforms.append(Transform3D(Basis(), center))

			match t:
				SimMap.Tile.HARD_WALL:
					hard_wall_transforms.append(Transform3D(Basis(), center))
				SimMap.Tile.WALL:
					var cell := Vector2i(x, y)
					_wall_indices[cell] = wall_transforms.size()
					wall_transforms.append(Transform3D(Basis(), center))
				SimMap.Tile.BUSH:
					var cell := Vector2i(x, y)
					_bush_indices[cell] = bush_transforms.size()
					bush_transforms.append(Transform3D(Basis(), center))
				SimMap.Tile.WATER:
					water_transforms.append(Transform3D(Basis(), center))

	# Создаем MultiMesh для каждого типа тайлов
	_floor_mm = _create_multimesh(MODEL_FLOOR, floor_transforms)
	_hard_wall_mm = _create_multimesh(MODEL_HARD_WALL, hard_wall_transforms)
	_wall_mm = _create_multimesh(MODEL_WALL, wall_transforms)
	_bush_mm = _create_multimesh(MODEL_BUSH_1, bush_transforms)
	_water_mm = _create_multimesh(MODEL_WATER, water_transforms)

	if _floor_mm != null:
		add_child(_floor_mm)
	if _hard_wall_mm != null:
		add_child(_hard_wall_mm)
	if _wall_mm != null:
		add_child(_wall_mm)
	if _bush_mm != null:
		add_child(_bush_mm)
	if _water_mm != null:
		add_child(_water_mm)


func on_tile_destroyed(cell: Vector2i, tile_type: int) -> void:
	if tile_type == SimMap.Tile.WALL and _wall_indices.has(cell):
		var idx: int = _wall_indices[cell]
		if _wall_mm != null and _wall_mm.multimesh != null:
			var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -100.0, 0.0))
			_wall_mm.multimesh.set_instance_transform(idx, hidden)
		_spawn_debris(Vector3(cell.x + 0.5, 0.4, cell.y + 0.5))

	elif tile_type == SimMap.Tile.BUSH and _bush_indices.has(cell):
		var idx: int = _bush_indices[cell]
		if _bush_mm != null and _bush_mm.multimesh != null:
			var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -100.0, 0.0))
			_bush_mm.multimesh.set_instance_transform(idx, hidden)


func on_tile_restored(cell: Vector2i, tile_type: int) -> void:
	if tile_type == SimMap.Tile.BUSH and _bush_indices.has(cell):
		var idx: int = _bush_indices[cell]
		if _bush_mm != null and _bush_mm.multimesh != null:
			var center := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
			_bush_mm.multimesh.set_instance_transform(idx, Transform3D(Basis(), center))


func _create_multimesh(model_path: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null

	var scn := load(model_path) as PackedScene
	if scn == null:
		push_error("MapView: не удалось загрузить модель " + model_path)
		return null

	var inst := scn.instantiate()
	var mesh: Mesh = null
	for c in inst.get_children():
		if c is MeshInstance3D:
			mesh = (c as MeshInstance3D).mesh
			break
	inst.free()

	if mesh == null:
		push_error("MapView: не найден MeshInstance3D в " + model_path)
		return null

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()

	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


func _load_debris_scenes() -> void:
	_debris_scenes.clear()
	for p in DEBRIS_PATHS:
		var scn := load(p) as PackedScene
		if scn != null:
			_debris_scenes.append(scn)


func _spawn_debris(pos_3d: Vector3) -> void:
	if _debris_scenes.is_empty():
		return

	for i in 4:
		var scn := _debris_scenes[i % _debris_scenes.size()]
		var node := scn.instantiate() as Node3D
		if node == null:
			continue
		add_child(node)
		node.position = pos_3d + Vector3(randf_range(-0.15, 0.15), 0.1, randf_range(-0.15, 0.15))

		var target_offset := Vector3(randf_range(-0.7, 0.7), randf_range(0.3, 0.6), randf_range(-0.7, 0.7))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "position", node.position + target_offset, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "rotation:y", randf_range(-PI, PI), 0.4)
		tw.tween_property(node, "scale", Vector3.ZERO, 0.25).set_delay(0.35)
		tw.chain().tween_callback(node.queue_free)
