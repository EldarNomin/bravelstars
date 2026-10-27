class_name MatchView
extends Node3D
## Главная сцена матча 3v3.
## Создает SimWorld, карту из low-poly моделей (MapView), героев (BrawlerView),
## снаряды, ботов (BotTeam) и интерфейс (MatchHUD + TouchControls).
## Выполняет тики симуляции с частотой 30 Гц и рендерит с интерполяцией на 60+ FPS.

const BALANCE_PATH: String = "res://data/balance/global.tres"
const HERO_LYNX: String = "res://data/brawlers/lynx.tres"
const HERO_ANVIL: String = "res://data/brawlers/anvil.tres"
const HERO_SHISHKA: String = "res://data/brawlers/shishka.tres"

const CAMERA_HEIGHT: float = 16.5
const CAMERA_Z_OFFSET: float = 11.55  ## height / tan(55°)
const CAMERA_LERP_SPEED: float = 8.0

@export var map_path: String = "res://data/maps/sawmill.json"

var world: SimWorld
var player: SimBrawler
var bot_team: BotTeam

var _map_view: MapView
var _camera: Camera3D
var _hud: MatchHUD
var _touch_controls: TouchControls

var _brawler_views: Dictionary = {}  ## id -> BrawlerView
var _projectile_views: Dictionary = {}  ## id -> Node3D
var _shard_nodes: Array[Node3D] = []

var _prev_brawler_pos: Dictionary = {}
var _prev_proj_pos: Dictionary = {}

var _acc: float = 0.0

# Прицеливание
var _aim_line: MeshInstance3D
var _aim_circle: MeshInstance3D
var _aim_line_mat: StandardMaterial3D
var _aim_circle_mat: StandardMaterial3D

# Ввод с клавиатуры/мыши для ПК
var _pending_attack: bool = false
var _pending_auto: bool = false
var _pending_super: bool = false


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_ui()
	_setup_aim_indicators()
	start_match()


func _setup_environment() -> void:
	# Освещение
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-55.0)) * Basis(Vector3.UP, deg_to_rad(35.0)),
		Vector3(0.0, 20.0, 0.0)
	)
	sun.shadow_enabled = true
	add_child(sun)

	# Окружение
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.72)

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 48.0
	_camera.position = Vector3(16.0, CAMERA_HEIGHT, 10.0 + CAMERA_Z_OFFSET)
	add_child(_camera)
	_camera.look_at(Vector3(16.0, 0.0, 10.0))


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UICanvas"
	add_child(canvas)

	_touch_controls = TouchControls.new()
	_touch_controls.camera = _camera
	_touch_controls.aim_updated.connect(_on_touch_aim_updated)
	_touch_controls.aim_ended.connect(_on_touch_aim_ended)
	canvas.add_child(_touch_controls)

	_hud = MatchHUD.new()
	_hud.restart_requested.connect(start_match)
	canvas.add_child(_hud)


func _setup_aim_indicators() -> void:
	_aim_line_mat = StandardMaterial3D.new()
	_aim_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_line_mat.albedo_color = Color(1.0, 0.88, 0.2, 0.65)
	_aim_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_aim_line = MeshInstance3D.new()
	var box := BoxMesh.new()
	_aim_line.mesh = box
	_aim_line.material_override = _aim_line_mat
	_aim_line.visible = false
	add_child(_aim_line)

	_aim_circle_mat = StandardMaterial3D.new()
	_aim_circle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_circle_mat.albedo_color = Color(0.95, 0.65, 0.2, 0.55)
	_aim_circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_aim_circle = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 0.03
	_aim_circle.mesh = cyl
	_aim_circle.material_override = _aim_circle_mat
	_aim_circle.visible = false
	add_child(_aim_circle)


func start_match() -> void:
	# Очистка предыдущего состояния
	for v in _brawler_views.values():
		(v as Node).queue_free()
	_brawler_views.clear()

	for p in _projectile_views.values():
		(p as Node).queue_free()
	_projectile_views.clear()

	for s in _shard_nodes:
		s.queue_free()
	_shard_nodes.clear()

	if _map_view != null:
		_map_view.queue_free()

	_prev_brawler_pos.clear()
	_prev_proj_pos.clear()

	# 1. Загрузка карты
	var sim_map := SimMap.load_json(map_path)
	var balance := load(BALANCE_PATH) as GlobalBalance

	# 2. Создание мира
	world = SimWorld.new(sim_map, 1, balance)

	# 3. Настройка режима матча (Heist или TeamFight)
	var mode_name: String = str(sim_map.meta.get("mode", "teamfight")).to_lower()
	if mode_name == "heist":
		var heist := Heist.new(12, 150.0, 3.0)
		world.mode = heist
		heist.setup(world)
	else:
		world.mode = TeamFight.new(10, 120.0, 3.0)

	# 4. Создание карты
	_map_view = MapView.new()
	add_child(_map_view)
	_map_view.build_map(sim_map)

	# 5. Создание команд 3v3
	var data_lynx := load(HERO_LYNX) as BrawlerData
	var data_anvil := load(HERO_ANVIL) as BrawlerData
	var data_shishka := load(HERO_SHISHKA) as BrawlerData

	# Команда 0: Игрок (Рысь) + 2 союзных бота (Наковальня, Шишка)
	player = world.add_brawler(data_lynx, 0)
	var ally_1 := world.add_brawler(data_anvil, 0)
	var ally_2 := world.add_brawler(data_shishka, 0)

	# Команда 1: 3 вражеских бота (Наковальня, Рысь, Шишка)
	var enemy_1 := world.add_brawler(data_anvil, 1)
	var enemy_2 := world.add_brawler(data_lynx, 1)
	var enemy_3 := world.add_brawler(data_shishka, 1)

	# 6. Инициализация BotTeam для 5 ботов
	bot_team = BotTeam.new(world)
	bot_team.add(ally_1, null, 11)
	bot_team.add(ally_2, null, 12)
	bot_team.add(enemy_1, null, 21)
	bot_team.add(enemy_2, null, 22)
	bot_team.add(enemy_3, null, 23)

	# 7. Создание визуальных представлений героев
	for b in world.brawlers:
		var bv := BrawlerView.new(b, b == player)
		add_child(bv)
		_brawler_views[b.id] = bv
		_prev_brawler_pos[b.id] = b.pos

	# Мгновенная центровка камеры на игроке
	var target_cam := Vector3(player.pos.x, CAMERA_HEIGHT, player.pos.y + CAMERA_Z_OFFSET)
	_camera.position = target_cam
	_camera.look_at(Vector3(player.pos.x, 0.0, player.pos.y))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_pending_attack = true
	if event.is_action_pressed("auto_attack"):
		_pending_auto = true
	if event.is_action_pressed("use_super"):
		_pending_super = true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		start_match()


func _process(delta: float) -> void:
	_acc += delta
	while _acc >= SimConstants.DT:
		_acc -= SimConstants.DT
		_sim_tick()

	var alpha := clampf(_acc / SimConstants.DT, 0.0, 1.0)
	_render(alpha, delta)


func _sim_tick() -> void:
	# 1. Сохраняем предыдущие позиции для интерполяции
	for b in world.brawlers:
		_prev_brawler_pos[b.id] = b.pos

	for pr in world.projectiles:
		_prev_proj_pos[pr.id] = pr.pos

	# 2. Ввод локального игрока (джойстики + клавиатура/мышь)
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mouse_aim := _get_mouse_ground() - player.pos
	var cmd := InputCommand.create(mv)

	if _pending_attack or _pending_auto:
		cmd.attack = true
		cmd.attack_aim = Vector2.ZERO if _pending_auto else mouse_aim

	if _pending_super:
		cmd.use_super = true
		cmd.super_aim = mouse_aim

	_pending_attack = false
	_pending_auto = false
	_pending_super = false

	# Опрашиваем сенсорные джойстики
	if _touch_controls != null and player != null:
		var touch_cmd := _touch_controls.build_command(player)
		if touch_cmd.move != Vector2.ZERO:
			cmd.move = touch_cmd.move
		if touch_cmd.attack:
			cmd.attack = true
			cmd.attack_aim = touch_cmd.attack_aim
		if touch_cmd.use_super:
			cmd.use_super = true
			cmd.super_aim = touch_cmd.super_aim

	# Передаем команду в симуляцию, если режим разрешает ввод
	if world.mode == null or world.mode.accepts_input():
		world.set_input(player.id, cmd)
	else:
		world.set_input(player.id, InputCommand.new())

	# 3. Боты
	if bot_team != null:
		bot_team.drive(world)

	# 4. Шаг симуляции
	world.step()

	# 5. Обработка событий симуляции
	for e in world.drain_events():
		_handle_sim_event(e)


func _handle_sim_event(e: Dictionary) -> void:
	var event_type: StringName = e.get("type", &"")
	match event_type:
		SimEvents.TILE_DESTROYED:
			var cell: Vector2i = e.get("cell", Vector2i(-1, -1))
			var tile: int = e.get("tile", 0)
			if _map_view != null:
				_map_view.on_tile_destroyed(cell, tile)
		SimEvents.TILE_RESTORED:
			var cell: Vector2i = e.get("cell", Vector2i(-1, -1))
			var tile: int = e.get("tile", 0)
			if _map_view != null:
				_map_view.on_tile_restored(cell, tile)


func _render(alpha: float, delta: float) -> void:
	# 1. Интерполяция позиций героев
	for b in world.brawlers:
		var bv: BrawlerView = _brawler_views.get(b.id)
		if bv == null:
			continue
		var prev_p: Vector2 = _prev_brawler_pos.get(b.id, b.pos)
		var p: Vector2 = prev_p.lerp(b.pos, alpha)
		bv.update_transform_interpolated(p, b.facing)
		bv.update_state(b, world, player.team)

	# 2. Интерполяция снарядов
	var active_proj_ids: Dictionary = {}
	for pr in world.projectiles:
		active_proj_ids[pr.id] = true
		var node: Node3D = _projectile_views.get(pr.id)
		if node == null:
			node = _create_projectile_node(pr)
			_projectile_views[pr.id] = node

		var prev_p: Vector2 = _prev_proj_pos.get(pr.id, pr.pos)
		var p: Vector2 = prev_p.lerp(pr.pos, alpha)

		var h: float = 0.5
		if pr.attack.kind == AttackData.Kind.LOB:
			var t := pr.lob_progress()
			h = 0.5 + 12.0 * t * (1.0 - t)

		node.position = Vector3(p.x, h, p.y)

	# Удаление завершенных снарядов
	for id: int in _projectile_views.keys():
		if not active_proj_ids.has(id):
			_projectile_views[id].queue_free()
			_projectile_views.erase(id)

	# 3. Отрисовка осколков кристаллов на земле (режим Heist)
	if world.mode is Heist:
		_render_heist_shards()

	# 4. Плавное следование камеры за игроком
	if player != null and _brawler_views.has(player.id):
		var target_pos := Vector3(player.pos.x, CAMERA_HEIGHT, player.pos.y + CAMERA_Z_OFFSET)
		_camera.position = _camera.position.lerp(target_pos, delta * CAMERA_LERP_SPEED)
		var look_target := Vector3(_camera.position.x, 0.0, _camera.position.z - CAMERA_Z_OFFSET)
		_camera.look_at(look_target)

	# 5. Обновление интерфейса
	if _hud != null:
		_hud.update_hud(world, player)


func _create_projectile_node(pr: SimProjectile) -> Node3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = pr.attack.projectile_radius
	sphere.height = pr.attack.projectile_radius * 2.0
	node.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col := BrawlerView.COLOR_TEAM_0 if pr.team == 0 else BrawlerView.COLOR_TEAM_1
	mat.albedo_color = col.lightened(0.3)
	node.material_override = mat

	add_child(node)
	return node


func _render_heist_shards() -> void:
	var heist := world.mode as Heist
	while _shard_nodes.size() < heist.shards.size():
		var prism := MeshInstance3D.new()
		var pmesh := PrismMesh.new()
		pmesh.size = Vector3(0.3, 0.5, 0.3)
		prism.mesh = pmesh

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.96, 0.68, 0.33)  ## Янтарь #F6AD55
		prism.material_override = mat

		add_child(prism)
		_shard_nodes.append(prism)

	while _shard_nodes.size() > heist.shards.size():
		var n := _shard_nodes.pop_back() as Node3D
		n.queue_free()

	for i in heist.shards.size():
		var s_pos: Vector2 = heist.shards[i]
		var node := _shard_nodes[i]
		node.position = Vector3(s_pos.x, 0.35, s_pos.y)
		node.rotation.y += 0.05


func _on_touch_aim_updated(
	action: StringName,
	aim_dir: Vector2,
	range_tiles: float,
	is_auto: bool
) -> void:
	if is_auto or aim_dir.is_zero_approx() or player == null or not player.alive:
		_aim_line.visible = false
		_aim_circle.visible = false
		return

	# Определяем тип атаки (навесная или прямая)
	var is_lob: bool = false
	var area_radius: float = 1.0

	if action == &"super":
		if player.data.super_attack != null:
			is_lob = player.data.super_attack.kind == AttackData.Kind.LOB
			area_radius = player.data.super_attack.area_radius
	else:
		if player.data.attack != null:
			is_lob = player.data.attack.kind == AttackData.Kind.LOB
			area_radius = player.data.attack.area_radius

	if is_lob:
		_aim_line.visible = false
		_aim_circle.visible = true
		var target_pos := player.pos + aim_dir * range_tiles
		_aim_circle.position = Vector3(target_pos.x, 0.05, target_pos.y)
		var cyl := _aim_circle.mesh as CylinderMesh
		cyl.top_radius = area_radius
		cyl.bottom_radius = area_radius
	else:
		_aim_circle.visible = false
		_aim_line.visible = true
		var box := _aim_line.mesh as BoxMesh
		box.size = Vector3(0.22, 0.04, range_tiles)
		var mid := player.pos + aim_dir * (range_tiles * 0.5)
		_aim_line.position = Vector3(mid.x, 0.05, mid.y)
		_aim_line.rotation = Vector3(0.0, atan2(aim_dir.x, aim_dir.y), 0.0)


func _on_touch_aim_ended(_action: StringName) -> void:
	_aim_line.visible = false
	_aim_circle.visible = false


func _get_mouse_ground() -> Vector2:
	if _camera == null:
		return player.pos if player != null else Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var normal := _camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return player.pos if player != null else Vector2.ZERO
	var t := -origin.y / normal.y
	var hit := origin + normal * t
	return Vector2(hit.x, hit.z)
