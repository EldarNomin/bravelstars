extends Node3D
## Отладочная сцена: рисует SimWorld примитивами и управляется с клавиатуры/мыши на ПК.
## Нужна, чтобы щупать ядро до появления настоящих view/UI (задачи Antigravity C-05..C-07).
##
## WASD — движение, ЛКМ — выстрел в сторону курсора, E — автоприцел,
## ПКМ/Пробел — супер в сторону курсора, R — перезапуск.

const MAP_PATH: String = "res://data/maps/_debug_arena.json"
const BRAWLER_PATH: String = "res://data/brawlers/_prototype.tres"
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.3, 0.3)]
const TILE_COLORS: Dictionary = {
	SimMap.Tile.WALL: Color(0.6, 0.4, 0.25),
	SimMap.Tile.HARD_WALL: Color(0.35, 0.35, 0.4),
	SimMap.Tile.BUSH: Color(0.2, 0.65, 0.25),
	SimMap.Tile.WATER: Color(0.2, 0.45, 0.85),
}
const TILE_HEIGHT: Dictionary = {
	SimMap.Tile.WALL: 1.0,
	SimMap.Tile.HARD_WALL: 1.2,
	SimMap.Tile.BUSH: 0.7,
	SimMap.Tile.WATER: 0.05,
}
const CAMERA_OFFSET: Vector3 = Vector3(0, 13, 7.5)
const DUMMY_FIRE_CHANCE: float = 0.03

var world: SimWorld
var player: SimBrawler

var _acc: float = 0.0
var _prev_pos: Dictionary = {}
var _tile_nodes: Dictionary = {}
var _brawler_nodes: Dictionary = {}
var _projectile_nodes: Dictionary = {}
var _materials: Dictionary = {}
var _pending_attack: bool = false
var _pending_auto: bool = false
var _pending_super: bool = false
var _dummy_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: Label = $HUD/Info


func _ready() -> void:
	_start()


func _start() -> void:
	for n in _tile_nodes.values() + _brawler_nodes.values() + _projectile_nodes.values():
		n.queue_free()
	_tile_nodes.clear()
	_brawler_nodes.clear()
	_projectile_nodes.clear()
	world = SimWorld.new(SimMap.load_json(MAP_PATH), 1)
	_dummy_rng.seed = 1
	var data: BrawlerData = load(BRAWLER_PATH)
	player = world.add_brawler(data, 0)
	world.add_brawler(data, 0)
	for _i in 3:
		world.add_brawler(data, 1)
	_build_map()
	for b in world.brawlers:
		_prev_pos[b.id] = b.pos


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_pending_attack = true
	if event.is_action_pressed("auto_attack"):
		_pending_auto = true
	if event.is_action_pressed("use_super"):
		_pending_super = true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_start()


func _process(delta: float) -> void:
	_acc += delta
	while _acc >= SimConstants.DT:
		_acc -= SimConstants.DT
		_sim_tick()
	_render(_acc / SimConstants.DT)


func _sim_tick() -> void:
	for b in world.brawlers:
		_prev_pos[b.id] = b.pos
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim := _mouse_ground() - player.pos
	var cmd := InputCommand.create(mv)
	if _pending_attack or _pending_auto:
		cmd.attack = true
		cmd.attack_aim = Vector2.ZERO if _pending_auto else aim
	if _pending_super:
		cmd.use_super = true
		cmd.super_aim = aim
	_pending_attack = false
	_pending_auto = false
	_pending_super = false
	world.set_input(player.id, cmd)
	_drive_dummies()
	world.step()
	for e in world.events:
		if e["type"] == "tile_destroyed" and _tile_nodes.has(e["cell"]):
			_tile_nodes[e["cell"]].queue_free()
			_tile_nodes.erase(e["cell"])


## Не ИИ ботов (это C-10), а манекены: стоят и иногда стреляют автоприцелом.
func _drive_dummies() -> void:
	for b in world.brawlers:
		if b == player or not b.alive:
			continue
		var cmd := InputCommand.new()
		cmd.attack = _dummy_rng.randf() < DUMMY_FIRE_CHANCE
		cmd.use_super = b.super_ready()
		world.set_input(b.id, cmd)


func _render(alpha: float) -> void:
	for b in world.brawlers:
		var node: Node3D = _brawler_nodes.get(b.id)
		if node == null:
			node = _make_brawler_node(b)
		var p: Vector2 = (_prev_pos.get(b.id, b.pos) as Vector2).lerp(b.pos, alpha)
		node.position = Vector3(p.x, 0, p.y)
		node.visible = b.alive and world.is_visible_to(player.team, b)
		var label: Label3D = node.get_node("Label")
		label.text = "%d\n%s" % [b.hp, "●".repeat(b.ammo) + "○".repeat(b.data.max_ammo - b.ammo)]
		if b.super_ready():
			label.text += " ★"
	var alive_ids := {}
	for pr in world.projectiles:
		alive_ids[pr.id] = true
		var node: Node3D = _projectile_nodes.get(pr.id)
		if node == null:
			node = _make_sphere(pr.attack.projectile_radius, TEAM_COLORS[pr.team % 2].lightened(0.4))
			_projectile_nodes[pr.id] = node
		var h := 0.5
		if pr.attack.kind == AttackData.Kind.LOB:
			var t := pr.lob_progress()
			h = 0.5 + 12.0 * t * (1.0 - t)
		node.position = Vector3(pr.pos.x, h, pr.pos.y)
	for id: int in _projectile_nodes.keys():
		if not alive_ids.has(id):
			_projectile_nodes[id].queue_free()
			_projectile_nodes.erase(id)
	var focus: Node3D = _brawler_nodes[player.id]
	_camera.position = focus.position + CAMERA_OFFSET
	_camera.look_at(focus.position)
	_hud.text = (
		"HP %d/%d   патроны %d   супер %d%%   убийств %d   смертей %d   тик %d\n"
		% [player.hp, player.data.max_hp, player.ammo, roundi(player.super_charge * 100),
			player.kills, player.deaths, world.tick]
		+ "WASD — бег, ЛКМ — выстрел, E — автоприцел, ПКМ/Пробел — супер, R — заново"
	)


func _mouse_ground() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var normal := _camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return player.pos
	var t := -origin.y / normal.y
	var hit := origin + normal * t
	return Vector2(hit.x, hit.z)


func _build_map() -> void:
	var m := world.map
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(m.width, m.height)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _material(Color(0.82, 0.76, 0.6))
	floor_mesh.position = Vector3(m.width * 0.5, 0, m.height * 0.5)
	add_child(floor_mesh)
	_tile_nodes[Vector2i(-1, -1)] = floor_mesh
	for y in m.height:
		for x in m.width:
			var t := m.get_tile(x, y)
			if not TILE_COLORS.has(t):
				continue
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			var h: float = TILE_HEIGHT[t]
			mesh.size = Vector3(1, h, 1)
			box.mesh = mesh
			box.material_override = _material(TILE_COLORS[t], t == SimMap.Tile.BUSH)
			box.position = Vector3(x + 0.5, h * 0.5, y + 0.5)
			add_child(box)
			_tile_nodes[Vector2i(x, y)] = box


func _make_brawler_node(b: SimBrawler) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = b.data.radius
	capsule.height = 1.2
	body.mesh = capsule
	body.position.y = 0.6
	body.material_override = _material(TEAM_COLORS[b.team % 2])
	root.add_child(body)
	var label := Label3D.new()
	label.name = "Label"
	label.position.y = 1.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	root.add_child(label)
	add_child(root)
	_brawler_nodes[b.id] = root
	return root


func _make_sphere(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	node.mesh = mesh
	node.material_override = _material(color)
	add_child(node)
	return node


func _material(color: Color, translucent: bool = false) -> StandardMaterial3D:
	var key := [color, translucent]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if translucent:
			mat.albedo_color.a = 0.75
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = mat
	return _materials[key]
