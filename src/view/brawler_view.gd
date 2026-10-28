class_name BrawlerView
extends Node3D
## Отображение одного героя на арене.
## Включает 3D-модель из assets/models/heroes/<id>.glb (или капсулу-фоллбэк),
## маркер команды под ногами по STYLE.md и биллборд с полосками HP/зарядов/супера над головой.

const COLOR_TEAM_0: Color = Color(0.17, 0.42, 0.69)  ## #2B6CB0 сапфир
const COLOR_TEAM_1: Color = Color(0.77, 0.19, 0.19)  ## #C53030 рубин
const COLOR_HP_ALLY: Color = Color(0.28, 0.73, 0.47)  ## #48BB78
const COLOR_HP_ENEMY: Color = Color(0.85, 0.22, 0.22)  ## красный
const COLOR_AMMO: Color = Color(0.92, 0.79, 0.29)  ## #ECC94B
const COLOR_SHARD: Color = Color(0.96, 0.68, 0.33)  ## #F6AD55
const COLOR_SUPER: Color = Color(1.0, 0.84, 0.0)  ## #FFD700
const ROTATION_LERP_SPEED: float = 18.0

var brawler_id: int = 0
var team: int = 0
var is_local_player: bool = false

var _model_container: Node3D
var _hero_instance: Node3D
var _anim_player: AnimationPlayer
var _muzzle_node: Node3D
var _head_node: Node3D
var _mesh_instances: Array[MeshInstance3D] = []

var _capsule_mesh: MeshInstance3D
var _capsule_mat: StandardMaterial3D
var _ground_marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _sprite_billboard: Sprite3D
var _sub_viewport: SubViewport
var _bar_drawer: Control

var _current_yaw: float = 0.0
var _is_playing_action: bool = false
var _is_moving: bool = false

var _cached_hp: int = -1
var _cached_max_hp: int = -1
var _cached_ammo: int = -1
var _cached_max_ammo: int = 3
var _cached_reload_progress: int = 0
var _cached_super_ready: bool = false
var _cached_shards: int = 0
var _cached_shield: bool = false


func _init(p_brawler: SimBrawler, p_is_local: bool = false) -> void:
	brawler_id = p_brawler.id
	team = p_brawler.team
	is_local_player = p_is_local
	_setup_nodes(p_brawler)


func _setup_nodes(p_brawler: SimBrawler) -> void:
	# 1. Контейнер для 3D-модели
	_model_container = Node3D.new()
	_model_container.name = "ModelContainer"
	add_child(_model_container)

	# Загрузка 3D-модели героя (A-05) по ID
	var hero_id: String = p_brawler.data.id.to_lower()
	var model_path: String = "res://assets/models/heroes/" + hero_id + ".glb"
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene != null:
			_hero_instance = scene.instantiate() as Node3D
			_model_container.add_child(_hero_instance)
			_anim_player = _find_animation_player(_hero_instance)
			if _anim_player != null:
				_anim_player.animation_finished.connect(_on_animation_finished)
				if _anim_player.has_animation(&"idle"):
					_anim_player.play(&"idle")
			_muzzle_node = _find_node_by_name(_hero_instance, "muzzle") as Node3D
			_head_node = _find_node_by_name(_hero_instance, "head") as Node3D
			_collect_meshes(_hero_instance)

	# Если модель отсутствует — фоллбэк на капсулу
	if _hero_instance == null:
		_capsule_mat = StandardMaterial3D.new()
		_capsule_mat.albedo_color = COLOR_TEAM_0 if team == 0 else COLOR_TEAM_1
		_capsule_mat.roughness = 0.4

		_capsule_mesh = MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = p_brawler.data.radius
		cap.height = 1.2
		_capsule_mesh.mesh = cap
		_capsule_mesh.position.y = 0.6
		_capsule_mesh.material_override = _capsule_mat
		_model_container.add_child(_capsule_mesh)

	# 2. Напольный маркер команды (STYLE.md: свои — кольцо, враги — треугольник)
	_setup_ground_marker()

	# 3. Биллборд интерфейса над головой (HP, заряды, супер)
	_setup_overhead_hud(p_brawler)


func _setup_ground_marker() -> void:
	_ground_marker = MeshInstance3D.new()
	_ground_marker.name = "GroundMarker"
	_ground_marker.position.y = 0.03

	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.albedo_color = COLOR_TEAM_0 if team == 0 else COLOR_TEAM_1
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.albedo_color.a = 0.75

	if team == 0:
		# Кольцо под ногами союзников (CylinderMesh с плоской высотой)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 0.55
		cyl.height = 0.02
		_ground_marker.mesh = cyl
	else:
		# Направленный треугольник под ногами противников (PrismMesh)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.8, 0.02, 0.9)
		_ground_marker.mesh = prism
		_ground_marker.rotation.x = 0.0

	_ground_marker.material_override = _marker_mat
	add_child(_ground_marker)


func _setup_overhead_hud(p_brawler: SimBrawler) -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(140, 48)
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub_viewport)

	_bar_drawer = Control.new()
	_bar_drawer.custom_minimum_size = Vector2(140, 48)
	_bar_drawer.draw.connect(_on_bar_draw)
	_sub_viewport.add_child(_bar_drawer)

	_sprite_billboard = Sprite3D.new()
	_sprite_billboard.name = "OverheadHUD"
	_sprite_billboard.position.y = 1.65
	_sprite_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite_billboard.no_depth_test = true
	_sprite_billboard.texture = _sub_viewport.get_texture()
	add_child(_sprite_billboard)

	_cached_max_hp = p_brawler.data.max_hp
	_cached_max_ammo = p_brawler.data.max_ammo


## Возвращает мировую 3D-позицию сокета вылета снарядов (muzzle)
func get_muzzle_global_position() -> Vector3:
	if _muzzle_node != null and is_instance_valid(_muzzle_node):
		return _muzzle_node.global_position
	return global_position + Vector3(0.0, 0.8, 0.0)


## Обновляет 3D-позицию с интерполяцией и плавным поворотом
func update_transform_interpolated(pos_2d: Vector2, facing: Vector2, delta: float = 0.0) -> void:
	position = Vector3(pos_2d.x, 0.0, pos_2d.y)
	if not facing.is_zero_approx():
		var target_angle := atan2(facing.x, facing.y)
		if delta > 0.0:
			var rot_factor := clampf(delta * ROTATION_LERP_SPEED, 0.0, 1.0)
			_current_yaw = lerp_angle(_current_yaw, target_angle, rot_factor)
		else:
			_current_yaw = target_angle

		_model_container.rotation = Vector3(0.0, _current_yaw, 0.0)
		if team != 0 and _ground_marker != null:
			_ground_marker.rotation = Vector3(0.0, _current_yaw, 0.0)

	# Позиционирование полоски HP над головой (по сокету head)
	if _head_node != null and is_instance_valid(_head_node):
		var head_y := _head_node.global_position.y - global_position.y
		if head_y > 0.5:
			_sprite_billboard.position.y = head_y + 0.35


## Воспроизведение анимации действия (attack, super)
func play_action(action_name: StringName) -> void:
	if _anim_player != null and _anim_player.has_animation(action_name):
		_is_playing_action = true
		_anim_player.play(action_name)


## Обработка гибели героя
func on_death() -> void:
	if _anim_player != null and _anim_player.has_animation(&"death"):
		_is_playing_action = true
		_anim_player.play(&"death")
	else:
		visible = false


## Обработка возрождения героя
func on_respawn() -> void:
	visible = true
	_is_playing_action = false
	_update_locomotion()


## Обновляет состояние движения (idle / run)
func update_locomotion(is_moving: bool) -> void:
	_is_moving = is_moving
	if _is_playing_action:
		return
	_update_locomotion()


func _update_locomotion() -> void:
	if _anim_player == null:
		return
	if _is_moving and _anim_player.has_animation(&"run"):
		if _anim_player.current_animation != &"run":
			_anim_player.play(&"run")
	elif _anim_player.has_animation(&"idle"):
		if _anim_player.current_animation != &"idle":
			_anim_player.play(&"idle")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"attack" or anim_name == &"super":
		_is_playing_action = false
		_update_locomotion()


## Обновляет состояние здоровья, зарядов, видимости
func update_state(brawler: SimBrawler, world: SimWorld, local_team: int) -> void:
	# 1. Видимость в кустах
	var is_visible_to_player := world.is_visible_to(local_team, brawler)
	if not is_visible_to_player or not brawler.alive:
		visible = false
		return

	visible = true

	# Проверяем нахождение в кусте
	var tile_idx := world.map.get_tile(int(brawler.pos.x), int(brawler.pos.y))
	var in_bush := tile_idx == SimMap.Tile.BUSH
	var is_friendly := brawler.team == local_team

	if in_bush and is_friendly:
		if _capsule_mat != null:
			_capsule_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_capsule_mat.albedo_color.a = 0.55
		for m: MeshInstance3D in _mesh_instances:
			m.transparency = 0.45
		_marker_mat.albedo_color.a = 0.4
	else:
		if _capsule_mat != null:
			_capsule_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_capsule_mat.albedo_color.a = 1.0
		for m: MeshInstance3D in _mesh_instances:
			m.transparency = 0.0
		_marker_mat.albedo_color.a = 0.75

	# 2. Кэшируем значения для перерисовки полосок
	var shards := int(brawler.mode_data.get("shards", 0))
	var has_shield := brawler.has_shield(world.tick)

	var needs_redraw: bool = (
		_cached_hp != brawler.hp
		or _cached_ammo != brawler.ammo
		or _cached_reload_progress != brawler.reload_progress
		or _cached_super_ready != brawler.super_ready()
		or _cached_shards != shards
		or _cached_shield != has_shield
	)

	_cached_hp = brawler.hp
	_cached_ammo = brawler.ammo
	_cached_reload_progress = brawler.reload_progress
	_cached_super_ready = brawler.super_ready()
	_cached_shards = shards
	_cached_shield = has_shield

	if needs_redraw:
		_bar_drawer.queue_redraw()


func _on_bar_draw() -> void:
	var total_w: float = 120.0
	var bar_h: float = 14.0
	var offset_x: float = 10.0
	var offset_y: float = 6.0

	# Фон полоски HP
	_bar_drawer.draw_rect(
		Rect2(offset_x - 1, offset_y - 1, total_w + 2, bar_h + 2),
		Color(0.1, 0.12, 0.15, 0.9)
	)

	# Заполнение HP
	var hp_ratio := clampf(float(_cached_hp) / float(maxi(1, _cached_max_hp)), 0.0, 1.0)
	var hp_color := COLOR_HP_ALLY if team == 0 else COLOR_HP_ENEMY
	if _cached_shield:
		hp_color = Color(0.4, 0.7, 1.0)  ## Цвет щита при возрождении

	_bar_drawer.draw_rect(Rect2(offset_x, offset_y, total_w * hp_ratio, bar_h), hp_color)

	# Значок формы команды слева от HP (STYLE.md §3)
	if team == 0:
		_bar_drawer.draw_circle(Vector2(offset_x + 6, offset_y + bar_h * 0.5), 4.0, Color.WHITE)
	else:
		var pts := PackedVector2Array([
			Vector2(offset_x + 2, offset_y + 3),
			Vector2(offset_x + 10, offset_y + 3),
			Vector2(offset_x + 6, offset_y + bar_h - 3)
		])
		_bar_drawer.draw_colored_polygon(pts, Color.WHITE)

	# Полоска боеприпасов (3 сегмента)
	var ammo_y := offset_y + bar_h + 3.0
	var ammo_h := 6.0
	var seg_gap := 3.0
	var seg_w := (total_w - seg_gap * (_cached_max_ammo - 1)) / float(_cached_max_ammo)

	for i in _cached_max_ammo:
		var sx := offset_x + i * (seg_w + seg_gap)
		# Фон сегмента
		_bar_drawer.draw_rect(Rect2(sx, ammo_y, seg_w, ammo_h), Color(0.15, 0.15, 0.18, 0.8))

		if i < _cached_ammo:
			# Полный заряд
			_bar_drawer.draw_rect(Rect2(sx, ammo_y, seg_w, ammo_h), COLOR_AMMO)
		elif i == _cached_ammo:
			# Перезаряжающийся сегмент
			var reload_ratio := clampf(float(_cached_reload_progress) / 1000.0, 0.0, 1.0)
			_bar_drawer.draw_rect(Rect2(sx, ammo_y, seg_w * reload_ratio, ammo_h), COLOR_AMMO.darkened(0.2))

	# Индикатор супера (если готов и это локальный игрок)
	if is_local_player and _cached_super_ready:
		_bar_drawer.draw_circle(Vector2(offset_x + total_w + 8, offset_y + 7), 6.0, COLOR_SUPER)
		_bar_drawer.draw_arc(
			Vector2(offset_x + total_w + 8, offset_y + 7),
			7.0,
			0.0,
			TAU,
			16,
			Color.WHITE,
			1.5
		)

	# Индикатор переносимых осколков (режим Heist / Добыча)
	if _cached_shards > 0:
		var shard_x := offset_x + total_w * 0.5
		var shard_pts := PackedVector2Array([
			Vector2(shard_x, offset_y - 8),
			Vector2(shard_x + 5, offset_y - 4),
			Vector2(shard_x, offset_y),
			Vector2(shard_x - 5, offset_y - 4)
		])
		_bar_drawer.draw_colored_polygon(shard_pts, COLOR_SHARD)


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name.to_lower() == target_name.to_lower():
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child)
