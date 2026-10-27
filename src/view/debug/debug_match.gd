extends Node3D
## ВРЕМЕННО лежит в папке Antigravity: заменяется настоящим view в C-05..C-07, потом удаляется.
## Отладочная сцена: рисует SimWorld примитивами и управляется с клавиатуры/мыши на ПК.
## Нужна, чтобы щупать ядро до появления настоящих view/UI (задачи Antigravity C-05..C-07).
##
## WASD — движение, ЛКМ — выстрел в сторону курсора, E — автоприцел,
## ПКМ/Пробел — супер в сторону курсора, R — новый матч, 1/2/3 — сменить героя и начать заново.
## Остальные 5 героев — боты (C-10), режим — бой команд до 10 убийств (G-01).

const MAP_PATH: String = "res://data/maps/_debug_arena.json"
const HEROES: Array[String] = ["lynx", "anvil", "shishka"]
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
var _bots: BotTeam
var _hero_index: int = 0
var _match_seed: int = 1

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
	_match_seed += 1
	world = SimWorld.new(SimMap.load_json(MAP_PATH), _match_seed, load("res://data/balance/global.tres"))
	world.mode = TeamFight.new()
	_bots = BotTeam.new(world)
	player = world.add_brawler(_hero(HEROES[_hero_index]), 0)
	for team in 2:
		for i in HEROES.size():
			if team == 0 and i == _hero_index:
				continue
			_bots.add(world.add_brawler(_hero(HEROES[i]), team), null, _match_seed)
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
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_R:
			_start()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_3:
			_hero_index = event.physical_keycode - KEY_1
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
	_bots.drive(world)
	world.step()
	for e in world.drain_events():
		if e["type"] == SimEvents.TILE_DESTROYED and _tile_nodes.has(e["cell"]):
			_tile_nodes[e["cell"]].queue_free()
			_tile_nodes.erase(e["cell"])
		elif e["type"] == SimEvents.TILE_RESTORED:
			var c: Vector2i = e["cell"]
			_make_tile(c.x, c.y, e["tile"])


func _hero(id: String) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id)


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
	var m := world.mode
	var status := ""
	if m.phase == GameMode.Phase.COUNTDOWN:
		status = "Старт через %d" % ceili(m.countdown_left(world))
	elif m.is_finished():
		status = "НИЧЬЯ" if m.winner < 0 else ("ПОБЕДА!" if m.winner == player.team else "Поражение")
		status += "  (R — ещё матч)"
	else:
		var secs_left := m.ticks_left / SimConstants.TICK_RATE
		status = "%d:%02d" % [secs_left / 60, secs_left % 60]
	_hud.text = (
		"СИНИЕ %d : %d КРАСНЫЕ   %s\n" % [m.scores[0], m.scores[1], status]
		+ "%s  HP %d/%d   патроны %d   супер %d%%\n"
		% [player.data.display_name, player.hp, player.data.max_hp, player.ammo,
			player.super_charge * 100 / SimConstants.SUPER_CHARGE_MAX]
		+ "WASD — бег, ЛКМ — выстрел, E — автоприцел, ПКМ/Пробел — супер, 1/2/3 — герой, R — заново"
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
			_make_tile(x, y, m.get_tile(x, y))


func _make_tile(x: int, y: int, t: int) -> void:
	if not TILE_COLORS.has(t):
		return
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
