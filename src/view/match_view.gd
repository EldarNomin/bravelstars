class_name MatchView
extends Node3D
## Главная сцена матча 3v3.
## Инициализирует матч через MatchSetup по Game.next_match.
## Отображает карту (MapView), героев (BrawlerView), 3D-снаряды и объекты (safe, mine, shards),
## интерфейс (MatchHUD + TouchControls). Выполняет тики симуляции с интерполяцией на 60+ FPS.

const BALANCE_PATH: String = "res://data/balance/global.tres"

const CAMERA_HEIGHT: float = 18.0
const CAMERA_Z_OFFSET: float = 12.60  ## height / tan(55°)
const CAMERA_FOV: float = 52.0
const CAMERA_LERP_SPEED: float = 8.0

@export var map_path: String = ""

var world: SimWorld
var player: SimBrawler
var bot_team: BotTeam

var _setup: MatchSetup
var _map_view: MapView
var _camera: Camera3D
var _hud: MatchHUD
var _touch_controls: TouchControls

var _brawler_views: Dictionary = {}  ## id -> BrawlerView
var _projectile_views: Dictionary = {}  ## id -> Node3D
var _shard_nodes: Array[Node3D] = []
var _structure_nodes: Array[Node3D] = []

var _prev_brawler_pos: Dictionary = {}
var _prev_proj_pos: Dictionary = {}

var _acc: float = 0.0
var _player_kills: int = 0
var _player_deaths: int = 0
var _result_saved: bool = false

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
	_camera.fov = CAMERA_FOV
	_camera.position = Vector3(16.5, CAMERA_HEIGHT, 9.5 + CAMERA_Z_OFFSET)
	add_child(_camera)
	_camera.look_at(Vector3(16.5, 0.0, 9.5))


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UICanvas"
	add_child(canvas)

	_touch_controls = TouchControls.new()
	_touch_controls.camera = _camera
	_touch_controls.aim_updated.connect(_on_touch_aim_updated)
	_touch_controls.aim_ended.connect(_on_touch_aim_ended)
	canvas.add_child(_touch_controls)

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	if hud_scene != null:
		_hud = hud_scene.instantiate() as MatchHUD
	else:
		_hud = MatchHUD.new()
	_hud.restart_requested.connect(_on_hud_restart_requested)
	_hud.lobby_requested.connect(_on_hud_lobby_requested)
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
	for v: Node in _brawler_views.values():
		v.queue_free()
	_brawler_views.clear()

	for p: Node in _projectile_views.values():
		p.queue_free()
	_projectile_views.clear()

	for s: Node in _shard_nodes:
		s.queue_free()
	_shard_nodes.clear()

	for st: Node in _structure_nodes:
		st.queue_free()
	_structure_nodes.clear()

	if _map_view != null:
		_map_view.queue_free()

	_prev_brawler_pos.clear()
	_prev_proj_pos.clear()
	_player_kills = 0
	_player_deaths = 0
	_result_saved = false

	# 1. Получение MatchConfig (через Game.next_match или дефолтный)
	var cfg: MatchConfig
	if has_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		cfg = g.get("next_match")
	if cfg == null:
		cfg = MatchConfig.make(&"teamfight")

	if not map_path.is_empty():
		cfg = cfg.duplicate()
		cfg.map_path = map_path
		var sm := SimMap.load_json(map_path)
		if sm != null and sm.meta.has("mode"):
			cfg.mode = StringName(sm.meta["mode"])

	# 2. Сборка матча через MatchSetup (устранение дублей создания мира/ботов)
	_setup = MatchSetup.create(cfg)
	world = _setup.world
	player = _setup.player
	bot_team = _setup.bots

	# 3. Создание карты
	_map_view = MapView.new()
	add_child(_map_view)
	_map_view.build_map(world.map)

	# 4. Спавн 3D-структур режима «Добыча» (шахта, сейфы, зоны сдачи)
	if world.mode is Heist:
		_setup_heist_structures(world.mode as Heist)

	# 5. Создание визуальных представлений героев (BrawlerView)
	for b: SimBrawler in world.brawlers:
		var bv := BrawlerView.new(b, b == player)
		add_child(bv)
		_brawler_views[b.id] = bv
		_prev_brawler_pos[b.id] = b.pos

	# 6. Мгновенная центровка камеры с учётом границ карты
	var cam_target := _get_clamped_camera_target()
	_camera.position = Vector3(cam_target.x, CAMERA_HEIGHT, cam_target.z + CAMERA_Z_OFFSET)
	_camera.look_at(cam_target)


func _setup_heist_structures(heist: Heist) -> void:
	# Шахта в центре
	var mine_scene := load("res://assets/models/fx/mine.glb") as PackedScene
	if mine_scene != null:
		var mine_node := mine_scene.instantiate() as Node3D
		mine_node.position = Vector3(heist.mine.x, 0.0, heist.mine.y)
		add_child(mine_node)
		_structure_nodes.append(mine_node)

	# Сейф команды 0 (синий)
	var safe_blue_scene := load("res://assets/models/fx/safe_blue.glb") as PackedScene
	if safe_blue_scene != null:
		var safe_0 := safe_blue_scene.instantiate() as Node3D
		safe_0.position = Vector3(heist.safes[0].x, 0.0, heist.safes[0].y)
		add_child(safe_0)
		_structure_nodes.append(safe_0)

	var zone_0 := _create_delivery_zone(heist.safes[0], Color(0.17, 0.42, 0.69, 0.35))
	add_child(zone_0)
	_structure_nodes.append(zone_0)

	# Сейф команды 1 (красный)
	var safe_red_scene := load("res://assets/models/fx/safe_red.glb") as PackedScene
	if safe_red_scene != null:
		var safe_1 := safe_red_scene.instantiate() as Node3D
		safe_1.position = Vector3(heist.safes[1].x, 0.0, heist.safes[1].y)
		add_child(safe_1)
		_structure_nodes.append(safe_1)

	var zone_1 := _create_delivery_zone(heist.safes[1], Color(0.77, 0.19, 0.19, 0.35))
	add_child(zone_1)
	_structure_nodes.append(zone_1)


func _create_delivery_zone(pos_2d: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Heist.SAFE_RADIUS
	cyl.bottom_radius = Heist.SAFE_RADIUS
	cyl.height = 0.02
	mi.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat

	mi.position = Vector3(pos_2d.x, 0.02, pos_2d.y)
	return mi


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_pending_attack = true
	if event.is_action_pressed("auto_attack"):
		_pending_auto = true
	if event.is_action_pressed("use_super"):
		_pending_super = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			# Переключение между картами режимов
			var cur_mode: StringName = _setup.config.mode if _setup != null else &"teamfight"
			var next_mode: StringName = &"heist" if cur_mode == &"teamfight" else &"teamfight"
			var maps := MatchConfig.maps_for_mode(next_mode)
			map_path = maps[0] if not maps.is_empty() else ""
			if has_node("/root/Game"):
				get_node("/root/Game").next_match = MatchConfig.make(next_mode, &"lynx", map_path)
			start_match()
		elif event.physical_keycode == KEY_R:
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
	for b: SimBrawler in world.brawlers:
		_prev_brawler_pos[b.id] = b.pos

	for pr: SimProjectile in world.projectiles:
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

	# 3. Шаг симуляции через MatchSetup.step (управление ботами и игроком)
	var accepts := world.mode == null or world.mode.accepts_input()
	var effective_cmd: InputCommand = cmd if accepts else InputCommand.new()
	_setup.step(effective_cmd)

	# 4. Обработка событий симуляции
	for e: Dictionary in world.drain_events():
		_handle_sim_event(e)

	# 5. Сохранение результата в Game.last_result по окончании матча
	if world.mode != null and world.mode.is_finished() and not _result_saved:
		_result_saved = true
		_record_last_result()


func _record_last_result() -> void:
	if not has_node("/root/Game"):
		return
	var mode_name: StringName = _setup.config.mode if _setup != null else &"teamfight"
	var hero_name: StringName = _setup.config.hero_id if _setup != null else &"lynx"
	var g: Node = get_node("/root/Game")
	g.set("last_result", {
		"win": world.mode.winner == player.team,
		"winner": world.mode.winner,
		"score_0": int(world.mode.scores.get(0, 0)),
		"score_1": int(world.mode.scores.get(1, 0)),
		"kills": _player_kills,
		"deaths": _player_deaths,
		"mode": mode_name,
		"hero_id": hero_name,
		"duration_sec": world.tick / SimConstants.TICK_RATE,
	})


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
		SimEvents.ATTACK:
			var bid: int = e.get("brawler", 0)
			var bv: BrawlerView = _brawler_views.get(bid)
			if bv != null:
				bv.play_action(&"attack")
		SimEvents.SUPER:
			var bid: int = e.get("brawler", 0)
			var bv: BrawlerView = _brawler_views.get(bid)
			if bv != null:
				bv.play_action(&"super")
		SimEvents.DEATH:
			var target_id: int = e.get("target", 0)
			var killer_id: int = e.get("killer", 0)
			if killer_id == player.id and target_id != player.id:
				_player_kills += 1
			if target_id == player.id:
				_player_deaths += 1

			var bv: BrawlerView = _brawler_views.get(target_id)
			if bv != null:
				bv.on_death()
		SimEvents.RESPAWN:
			var bid: int = e.get("brawler", 0)
			var bv: BrawlerView = _brawler_views.get(bid)
			if bv != null:
				bv.on_respawn()


func _render(alpha: float, delta: float) -> void:
	if world == null:
		return

	# 1. Интерполяция позиций героев
	for b: SimBrawler in world.brawlers:
		var bv: BrawlerView = _brawler_views.get(b.id)
		if bv == null:
			continue
		var prev_p: Vector2 = _prev_brawler_pos.get(b.id, b.pos)
		var p: Vector2 = prev_p.lerp(b.pos, alpha)
		bv.update_transform_interpolated(p, b.facing, delta)
		bv.update_state(b, world, player.team)
		var is_moving: bool = (b.pos - prev_p).length_squared() > 0.0001
		bv.update_locomotion(is_moving)

	# 2. Интерполяция снарядов
	var active_proj_ids: Dictionary = {}
	for pr: SimProjectile in world.projectiles:
		active_proj_ids[pr.id] = true
		var node: Node3D = _projectile_views.get(pr.id)
		if node == null:
			node = _create_projectile_node(pr)
			_projectile_views[pr.id] = node

		var prev_p: Vector2 = _prev_proj_pos.get(pr.id, pr.pos)
		var p: Vector2 = prev_p.lerp(pr.pos, alpha)

		var h: float = 0.8
		if pr.attack.kind == AttackData.Kind.LOB:
			var t := pr.lob_progress()
			h = lerp(0.8, 0.35, t) + 12.0 * t * (1.0 - t)
			node.rotation.x += delta * 12.0
			node.rotation.z += delta * 6.0

		node.position = Vector3(p.x, h, p.y)

	# Удаление завершенных снарядов
	for id: int in _projectile_views.keys():
		if not active_proj_ids.has(id):
			_projectile_views[id].queue_free()
			_projectile_views.erase(id)

	# 3. Отрисовка осколков кристаллов на земле (режим Heist)
	if world.mode is Heist:
		_render_heist_shards(delta)

	# 4. Плавное следование камеры за игроком с ограничением по границам карты
	if player != null and _brawler_views.has(player.id):
		var look_target := _get_clamped_camera_target()
		var target_pos := Vector3(look_target.x, CAMERA_HEIGHT, look_target.z + CAMERA_Z_OFFSET)
		var factor := clampf(delta * CAMERA_LERP_SPEED, 0.0, 1.0)
		_camera.position = _camera.position.lerp(target_pos, factor)
		var look_pt := Vector3(_camera.position.x, 0.0, _camera.position.z - CAMERA_Z_OFFSET)
		_camera.look_at(look_pt)

	# 5. Обновление интерфейса
	if _hud != null:
		_hud.update_hud(world, player, _player_kills, _player_deaths)


## Вычисляет точку фокуса камеры с ограничением видимой области границами карты
func _get_clamped_camera_target() -> Vector3:
	if world == null or world.map == null:
		var px := player.pos.x if player != null else 16.5
		var py := player.pos.y if player != null else 9.5
		return Vector3(px, 0.0, py)

	var map_w := float(world.map.width)
	var map_h := float(world.map.height)

	var vp_size := Vector2(1280, 720)
	if get_viewport() != null:
		vp_size = get_viewport().get_visible_rect().size
	var aspect := vp_size.x / maxf(1.0, vp_size.y)

	# Вычисляем видимую область на земле (STYLE.md §6)
	var half_x := 10.72 * aspect
	var forward_z := 19.87
	var backward_z := 9.75
	var margin := 1.5

	var min_cx := half_x - margin
	var max_cx := map_w - half_x + margin
	var target_x: float
	if min_cx >= max_cx:
		target_x = map_w * 0.5
	else:
		var px := player.pos.x if player != null else map_w * 0.5
		target_x = clampf(px, min_cx, max_cx)

	var min_cz := forward_z - margin
	var max_cz := map_h - backward_z + margin
	var target_z: float
	if min_cz >= max_cz:
		target_z = map_h * 0.5
	else:
		var py := player.pos.y if player != null else map_h * 0.5
		target_z = clampf(py, min_cz, max_cz)

	return Vector3(target_x, 0.0, target_z)


func _create_projectile_node(pr: SimProjectile) -> Node3D:
	var owner_hero_id := &""
	for b: SimBrawler in world.brawlers:
		if b.id == pr.owner_id:
			owner_hero_id = b.data.id
			break

	var model_name: String = ""
	if pr.attack.kind == AttackData.Kind.LOB:
		model_name = "pinecone_super.glb" if pr.is_super else "pinecone.glb"
	elif owner_hero_id == &"anvil" or pr.attack.projectile_count > 1:
		model_name = "anvil_pellet.glb"
	else:
		model_name = "lynx_bullet.glb"

	var scene := load("res://assets/models/fx/" + model_name) as PackedScene
	var node: Node3D
	if scene != null:
		node = scene.instantiate() as Node3D
	else:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = pr.attack.projectile_radius
		sphere.height = pr.attack.projectile_radius * 2.0
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var col := BrawlerView.COLOR_TEAM_0 if pr.team == 0 else BrawlerView.COLOR_TEAM_1
		mat.albedo_color = col.lightened(0.3)
		mi.material_override = mat
		node = mi

	if model_name == "lynx_bullet.glb" and not pr.dir.is_zero_approx():
		node.rotation.y = atan2(-pr.dir.x, -pr.dir.y)

	var bv: BrawlerView = _brawler_views.get(pr.owner_id)
	if bv != null:
		node.position = bv.get_muzzle_global_position()
	else:
		node.position = Vector3(pr.pos.x, 0.8, pr.pos.y)

	add_child(node)
	return node


func _render_heist_shards(delta: float) -> void:
	var heist := world.mode as Heist
	var shard_scene := load("res://assets/models/fx/loot_shard.glb") as PackedScene

	while _shard_nodes.size() < heist.shards.size():
		var node: Node3D
		if shard_scene != null:
			node = shard_scene.instantiate() as Node3D
		else:
			var prism := MeshInstance3D.new()
			var pmesh := PrismMesh.new()
			pmesh.size = Vector3(0.3, 0.5, 0.3)
			prism.mesh = pmesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.96, 0.68, 0.33)  ## Янтарь #F6AD55
			prism.material_override = mat
			node = prism

		add_child(node)
		_shard_nodes.append(node)

	while _shard_nodes.size() > heist.shards.size():
		var n := _shard_nodes.pop_back() as Node3D
		n.queue_free()

	for i: int in heist.shards.size():
		var s_pos: Vector2 = heist.shards[i]
		var node := _shard_nodes[i]
		node.position = Vector3(s_pos.x, 0.35, s_pos.y)
		node.rotation.y += delta * 3.0


func _on_hud_restart_requested() -> void:
	if has_node("/root/Game"):
		var cfg: MatchConfig = get_node("/root/Game").get("next_match")
		if cfg != null:
			var maps := MatchConfig.maps_for_mode(cfg.mode)
			if not maps.is_empty():
				cfg.map_path = maps[randi() % maps.size()]
	start_match()


func _on_hud_lobby_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")


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
