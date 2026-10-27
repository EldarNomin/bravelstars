class_name TouchControls
extends Control
## Сенсорные элементы управления: виртуальные джойстики движения, атаки и супер.
##
## Левый джойстик: всплывает в месте касания левой половины экрана.
## Правый джойстик: атака (тап — автоприцел, оттягивание — прицел в направлении).
## Кнопка супера: активируется при brawler.super_ready(), аналогичная механика.
## Метод build_command(brawler: SimBrawler) -> InputCommand опрашивается раз в тик.

signal aim_started(action: StringName)
signal aim_updated(action: StringName, aim_direction: Vector2, range_tiles: float, is_auto: bool)
signal aim_ended(action: StringName)

const MOVE_RADIUS: float = 80.0
const ATTACK_RADIUS: float = 80.0
const SUPER_RADIUS: float = 55.0
const DEAD_ZONE_RATIO: float = 0.10

@export var camera: Camera3D

var _move_pointer: int = -1
var _move_base_pos: Vector2 = Vector2.ZERO
var _move_knob_pos: Vector2 = Vector2.ZERO
var _move_active: bool = false
var _move_vector: Vector2 = Vector2.ZERO

var _attack_pointer: int = -1
var _attack_start_pos: Vector2 = Vector2.ZERO
var _attack_drag_vec: Vector2 = Vector2.ZERO
var _attack_is_dragged: bool = false
var _pending_attack: bool = false
var _pending_attack_is_aimed: bool = false
var _pending_attack_dir: Vector2 = Vector2.ZERO

var _super_pointer: int = -1
var _super_start_pos: Vector2 = Vector2.ZERO
var _super_drag_vec: Vector2 = Vector2.ZERO
var _super_is_dragged: bool = false
var _pending_super: bool = false
var _pending_super_is_aimed: bool = false
var _pending_super_dir: Vector2 = Vector2.ZERO

var _last_super_ready: bool = false
var _cached_brawler: SimBrawler


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	_draw_move_joystick()
	_draw_attack_joystick()
	_draw_super_button()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_down(touch.index, touch.position)
		else:
			_handle_touch_up(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_handle_drag(drag.index, drag.position)


## Формирует InputCommand для симуляции на текущий тик.
## Не пишет в SimWorld напрямую.
func build_command(brawler: SimBrawler) -> InputCommand:
	if brawler != null:
		_cached_brawler = brawler
		_last_super_ready = brawler.super_ready()

	var move_map := screen_to_map(_move_vector) if not _move_vector.is_zero_approx() else Vector2.ZERO
	var cmd := InputCommand.create(move_map.limit_length(1.0))

	if _pending_attack:
		cmd.attack = true
		if _pending_attack_is_aimed:
			var range_val := _get_attack_range(brawler)
			cmd.attack_aim = _pending_attack_dir * range_val
		else:
			cmd.attack_aim = Vector2.ZERO
		_pending_attack = false
		_pending_attack_is_aimed = false

	if _pending_super:
		cmd.use_super = true
		if _pending_super_is_aimed:
			var range_val := _get_super_range(brawler)
			cmd.super_aim = _pending_super_dir * range_val
		else:
			cmd.super_aim = Vector2.ZERO
		_pending_super = false
		_pending_super_is_aimed = false

	queue_redraw()
	return cmd


## Преобразует экранное направление джойстика в вектор клеток карты с учётом поворота камеры.
func screen_to_map(screen_dir: Vector2) -> Vector2:
	if screen_dir.is_zero_approx():
		return Vector2.ZERO

	var cam := camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()

	if cam == null:
		return screen_dir

	var right_3d := cam.global_transform.basis.x
	var forward_3d := -cam.global_transform.basis.z
	var right_2d := Vector2(right_3d.x, right_3d.z)
	var forward_2d := Vector2(forward_3d.x, forward_3d.z)

	if right_2d.is_zero_approx() or forward_2d.is_zero_approx():
		return screen_dir

	right_2d = right_2d.normalized()
	forward_2d = forward_2d.normalized()

	# На экране Y направлен вниз, поэтому -screen_dir.y — это вперёд от игрока
	var map_dir := right_2d * screen_dir.x + forward_2d * (-screen_dir.y)
	return map_dir.normalized() * screen_dir.length()


## Вспомогательные методы симуляции касаний (для тестов и скриптов)
func simulate_touch_down(index: int, pos: Vector2) -> void:
	_handle_touch_down(index, pos)


func simulate_drag(index: int, pos: Vector2) -> void:
	_handle_drag(index, pos)


func simulate_touch_up(index: int, pos: Vector2) -> void:
	_handle_touch_up(index, pos)


func get_attack_center() -> Vector2:
	var size := _get_screen_size()
	return Vector2(size.x - 130.0, size.y - 130.0)


func get_super_center() -> Vector2:
	var size := _get_screen_size()
	return Vector2(size.x - 245.0, size.y - 110.0)


func get_default_move_center() -> Vector2:
	var size := _get_screen_size()
	return Vector2(130.0, size.y - 130.0)


func get_move_radius() -> float:
	return MOVE_RADIUS


func get_attack_radius() -> float:
	return ATTACK_RADIUS


func get_super_radius() -> float:
	return SUPER_RADIUS


func get_dead_zone_ratio() -> float:
	return DEAD_ZONE_RATIO


func is_super_ready() -> bool:
	return _last_super_ready


func set_super_ready(ready: bool) -> void:
	_last_super_ready = ready
	queue_redraw()


# ------------------------------------------------------------------------------
# Обработка ввода
# ------------------------------------------------------------------------------

func _handle_touch_down(index: int, pos: Vector2) -> void:
	var super_center := get_super_center()
	var attack_center := get_attack_center()
	var screen_size := _get_screen_size()

	# 1. Проверяем попадание по кнопке супера (радиус с запасом на палец)
	if pos.distance_to(super_center) <= SUPER_RADIUS * 1.3:
		if _super_pointer == -1 and _last_super_ready:
			_super_pointer = index
			_super_start_pos = super_center
			_super_drag_vec = Vector2.ZERO
			_super_is_dragged = false
			aim_started.emit(&"super")
			queue_redraw()
			return

	# 2. Проверяем попадание по правому джойстику атаки
	if pos.distance_to(attack_center) <= ATTACK_RADIUS * 1.5 or pos.x >= screen_size.x * 0.5:
		if _attack_pointer == -1:
			_attack_pointer = index
			_attack_start_pos = attack_center if pos.distance_to(attack_center) <= ATTACK_RADIUS * 1.5 else pos
			_attack_drag_vec = Vector2.ZERO
			_attack_is_dragged = false
			aim_started.emit(&"attack")
			queue_redraw()
			return

	# 3. Левая половина экрана — джойстик движения
	if pos.x < screen_size.x * 0.5:
		if _move_pointer == -1:
			_move_pointer = index
			_move_base_pos = pos
			_move_knob_pos = pos
			_move_active = true
			_move_vector = Vector2.ZERO
			queue_redraw()


func _handle_drag(index: int, pos: Vector2) -> void:
	if index == _move_pointer:
		var delta := pos - _move_base_pos
		var dist := delta.length()
		if dist > MOVE_RADIUS:
			_move_knob_pos = _move_base_pos + delta.normalized() * MOVE_RADIUS
		else:
			_move_knob_pos = pos

		var dead_zone := MOVE_RADIUS * DEAD_ZONE_RATIO
		if dist <= dead_zone:
			_move_vector = Vector2.ZERO
		else:
			var norm_len := clampf((dist - dead_zone) / (MOVE_RADIUS - dead_zone), 0.0, 1.0)
			_move_vector = delta.normalized() * norm_len
		queue_redraw()

	elif index == _attack_pointer:
		var delta := pos - _attack_start_pos
		var dist := delta.length()
		_attack_drag_vec = delta
		var dead_zone := ATTACK_RADIUS * DEAD_ZONE_RATIO
		if dist > dead_zone:
			_attack_is_dragged = true
			var dir := delta.normalized()
			var map_dir := screen_to_map(dir)
			aim_updated.emit(&"attack", map_dir, _get_attack_range(_cached_brawler), false)
		else:
			_attack_is_dragged = false
			aim_updated.emit(&"attack", Vector2.ZERO, 0.0, true)
		queue_redraw()

	elif index == _super_pointer:
		var delta := pos - _super_start_pos
		var dist := delta.length()
		_super_drag_vec = delta
		var dead_zone := SUPER_RADIUS * DEAD_ZONE_RATIO
		if dist > dead_zone:
			_super_is_dragged = true
			var dir := delta.normalized()
			var map_dir := screen_to_map(dir)
			aim_updated.emit(&"super", map_dir, _get_super_range(_cached_brawler), false)
		else:
			_super_is_dragged = false
			aim_updated.emit(&"super", Vector2.ZERO, 0.0, true)
		queue_redraw()


func _handle_touch_up(index: int, _pos: Vector2) -> void:
	if index == _move_pointer:
		_move_pointer = -1
		_move_active = false
		_move_vector = Vector2.ZERO
		queue_redraw()

	elif index == _attack_pointer:
		_attack_pointer = -1
		aim_ended.emit(&"attack")
		_pending_attack = true
		if _attack_is_dragged and not _attack_drag_vec.is_zero_approx():
			_pending_attack_is_aimed = true
			_pending_attack_dir = screen_to_map(_attack_drag_vec.normalized())
		else:
			_pending_attack_is_aimed = false
			_pending_attack_dir = Vector2.ZERO
		_attack_drag_vec = Vector2.ZERO
		_attack_is_dragged = false
		queue_redraw()

	elif index == _super_pointer:
		_super_pointer = -1
		aim_ended.emit(&"super")
		_pending_super = true
		if _super_is_dragged and not _super_drag_vec.is_zero_approx():
			_pending_super_is_aimed = true
			_pending_super_dir = screen_to_map(_super_drag_vec.normalized())
		else:
			_pending_super_is_aimed = false
			_pending_super_dir = Vector2.ZERO
		_super_drag_vec = Vector2.ZERO
		_super_is_dragged = false
		queue_redraw()


# ------------------------------------------------------------------------------
# Отрисовка
# ------------------------------------------------------------------------------

func _draw_move_joystick() -> void:
	if _move_active:
		draw_circle(_move_base_pos, MOVE_RADIUS, Color(0.15, 0.18, 0.22, 0.45))
		draw_arc(_move_base_pos, MOVE_RADIUS, 0.0, TAU, 32, Color(0.85, 0.9, 1.0, 0.6), 2.0)
		draw_circle(_move_knob_pos, MOVE_RADIUS * 0.38, Color(0.95, 0.95, 1.0, 0.75))
	else:
		var center := get_default_move_center()
		draw_circle(center, MOVE_RADIUS, Color(0.15, 0.18, 0.22, 0.2))
		draw_arc(center, MOVE_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.3), 1.5)
		draw_circle(center, MOVE_RADIUS * 0.35, Color(1.0, 1.0, 1.0, 0.35))


func _draw_attack_joystick() -> void:
	var center := get_attack_center()
	var knob := center
	if _attack_pointer != -1:
		knob = center + _attack_drag_vec.limit_length(ATTACK_RADIUS)

	draw_circle(center, ATTACK_RADIUS, Color(0.75, 0.2, 0.2, 0.35))
	draw_arc(center, ATTACK_RADIUS, 0.0, TAU, 32, Color(1.0, 0.35, 0.35, 0.7), 2.5)
	draw_circle(knob, ATTACK_RADIUS * 0.4, Color(1.0, 0.4, 0.4, 0.85))


func _draw_super_button() -> void:
	var center := get_super_center()
	var knob := center
	if _super_pointer != -1:
		knob = center + _super_drag_vec.limit_length(SUPER_RADIUS)

	var ready := _last_super_ready
	var bg_color := Color(0.9, 0.75, 0.1, 0.45) if ready else Color(0.3, 0.3, 0.35, 0.25)
	var rim_color := Color(1.0, 0.9, 0.2, 0.95) if ready else Color(0.5, 0.5, 0.55, 0.4)
	var knob_color := Color(1.0, 0.85, 0.2, 0.9) if ready else Color(0.45, 0.45, 0.5, 0.5)

	draw_circle(center, SUPER_RADIUS, bg_color)
	draw_arc(center, SUPER_RADIUS, 0.0, TAU, 32, rim_color, 3.0 if ready else 1.5)
	draw_circle(knob, SUPER_RADIUS * 0.42, knob_color)


# ------------------------------------------------------------------------------
# Вспомогательные методы
# ------------------------------------------------------------------------------

func _get_screen_size() -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var s := get_viewport_rect().size
		if s.x > 10.0 and s.y > 10.0:
			return s
	return Vector2(1152.0, 648.0)


func _get_attack_range(brawler: SimBrawler) -> float:
	if brawler != null and brawler.data != null and brawler.data.attack != null:
		return brawler.data.attack.range_tiles
	return 7.0


func _get_super_range(brawler: SimBrawler) -> float:
	if brawler != null and brawler.data != null:
		if brawler.data.super_attack != null:
			return brawler.data.super_attack.range_tiles
		if brawler.ability is DashSuper:
			return DashSuper.DEFAULT_DISTANCE
	return 5.0
