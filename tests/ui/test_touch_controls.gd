extends GutTest

var _tc: TouchControls
var _brawler: SimBrawler
var _data: BrawlerData


func before_each() -> void:
	_tc = TouchControls.new()
	add_child_autofree(_tc)

	_data = BrawlerData.new()
	_data.id = &"test_hero"
	_data.max_hp = 3000
	_data.move_speed = 2.4

	var atk := AttackData.new()
	atk.kind = AttackData.Kind.STRAIGHT
	atk.damage = 800
	atk.range_tiles = 8.0
	_data.attack = atk

	var sup := AttackData.new()
	sup.kind = AttackData.Kind.STRAIGHT
	sup.damage = 1500
	sup.range_tiles = 10.0
	_data.super_attack = sup

	_brawler = SimBrawler.new(1, 0, _data, Vector2(10.0, 10.0))


func test_tap_results_in_zero_aim() -> void:
	var center := _tc.get_attack_center()
	_tc.simulate_touch_down(0, center)
	_tc.simulate_touch_up(0, center)

	var cmd := _tc.build_command(_brawler)
	assert_true(cmd.attack, "Атака должна быть активирована по тапу")
	assert_eq(cmd.attack_aim, Vector2.ZERO, "При коротком тапе прицел должен быть нулевым (автоприцел)")


func test_drag_half_radius_results_in_direction_times_range() -> void:
	var center := _tc.get_attack_center()
	var half_radius := _tc.get_attack_radius() * 0.5
	var drag_pos := center + Vector2(half_radius, 0.0)

	_tc.simulate_touch_down(0, center)
	_tc.simulate_drag(0, drag_pos)
	_tc.simulate_touch_up(0, drag_pos)

	var cmd := _tc.build_command(_brawler)
	assert_true(cmd.attack, "Атака должна быть активирована")
	var expected_aim := Vector2(1.0, 0.0) * _data.attack.range_tiles
	assert_almost_eq(cmd.attack_aim.x, expected_aim.x, 0.001, "Координата X прицела")
	assert_almost_eq(cmd.attack_aim.y, expected_aim.y, 0.001, "Координата Y прицела")


func test_dead_zone_move_joystick() -> void:
	var touch_pos := Vector2(150.0, 300.0)
	_tc.simulate_touch_down(0, touch_pos)

	# 1. Оттягивание внутри мёртвой зоны (5% < 10%)
	var inside_deadzone := touch_pos + Vector2(_tc.get_move_radius() * 0.05, 0.0)
	_tc.simulate_drag(0, inside_deadzone)
	var cmd_idle := _tc.build_command(_brawler)
	assert_eq(cmd_idle.move, Vector2.ZERO, "В мёртвой зоне вектор движения должен быть нулевым")

	# 2. Оттягивание за пределами мёртвой зоны (50% > 10%)
	var outside_deadzone := touch_pos + Vector2(_tc.get_move_radius() * 0.5, 0.0)
	_tc.simulate_drag(0, outside_deadzone)
	var cmd_move := _tc.build_command(_brawler)
	assert_gt(cmd_move.move.length(), 0.0, "За пределами мёртвой зоны движение активно")
	assert_lte(cmd_move.move.length(), 1.0, "Длина вектора движения не превышает 1.0")
	assert_almost_eq(cmd_move.move.y, 0.0, 0.001)

	_tc.simulate_touch_up(0, outside_deadzone)
	var cmd_released := _tc.build_command(_brawler)
	assert_eq(cmd_released.move, Vector2.ZERO, "После отпускания движение останавливается")


func test_dead_zone_attack_stick_counts_as_tap() -> void:
	var center := _tc.get_attack_center()
	# Оттягивание на 5% радиуса (в пределах 10% мёртвой зоны)
	var small_drag := center + Vector2(_tc.get_attack_radius() * 0.05, 0.0)

	_tc.simulate_touch_down(0, center)
	_tc.simulate_drag(0, small_drag)
	_tc.simulate_touch_up(0, small_drag)

	var cmd := _tc.build_command(_brawler)
	assert_true(cmd.attack, "Атака должна сработать")
	assert_eq(cmd.attack_aim, Vector2.ZERO, "В мёртвой зоне прицел = автоприцел")


func test_super_button_disabled_when_not_ready() -> void:
	_brawler.super_charge = 0
	assert_false(_brawler.super_ready())

	var center := _tc.get_super_center()
	_tc.simulate_touch_down(0, center)
	_tc.simulate_touch_up(0, center)

	var cmd := _tc.build_command(_brawler)
	assert_false(cmd.use_super, "Супер не должен срабатывать, когда он не готов")


func test_super_button_tap_and_drag_when_ready() -> void:
	_brawler.super_charge = SimConstants.SUPER_CHARGE_MAX
	assert_true(_brawler.super_ready())
	_tc.set_super_ready(true)

	var center := _tc.get_super_center()

	# Тап по готовому суперу -> автоприцел супера
	_tc.simulate_touch_down(0, center)
	_tc.simulate_touch_up(0, center)
	var cmd_tap := _tc.build_command(_brawler)
	assert_true(cmd_tap.use_super, "Супер должен активироваться")
	assert_eq(cmd_tap.super_aim, Vector2.ZERO, "Тап по суперу = автоприцел (Vector2.ZERO)")

	# Оттягивание супера вверх на половину радиуса
	var half_radius := _tc.get_super_radius() * 0.5
	var drag_up := center + Vector2(0.0, -half_radius)
	_tc.simulate_touch_down(0, center)
	_tc.simulate_drag(0, drag_up)
	_tc.simulate_touch_up(0, drag_up)

	var cmd_drag := _tc.build_command(_brawler)
	assert_true(cmd_drag.use_super, "Супер должен активироваться")
	var expected_super := Vector2(0.0, -1.0) * _data.super_attack.range_tiles
	assert_almost_eq(cmd_drag.super_aim.x, expected_super.x, 0.001)
	assert_almost_eq(cmd_drag.super_aim.y, expected_super.y, 0.001)


func test_multitouch_move_and_attack_simultaneously() -> void:
	# Палец 0: бег влево
	var move_pos := Vector2(100.0, 300.0)
	_tc.simulate_touch_down(0, move_pos)
	_tc.simulate_drag(0, move_pos + Vector2(-_tc.get_move_radius() * 0.8, 0.0))

	# Палец 1: прицеливание атаки вниз
	var attack_center := _tc.get_attack_center()
	_tc.simulate_touch_down(1, attack_center)
	_tc.simulate_drag(1, attack_center + Vector2(0.0, _tc.get_attack_radius() * 0.6))

	# Пока палец 1 удерживается, выстрела ещё нет, но бег уже работает
	var cmd1 := _tc.build_command(_brawler)
	assert_lt(cmd1.move.x, 0.0, "Бег влево активен")
	assert_false(cmd1.attack, "Атака ещё не отпущена")

	# Отпускаем палец 1 (выстрел) при продолжающемся беге
	_tc.simulate_touch_up(1, attack_center + Vector2(0.0, _tc.get_attack_radius() * 0.6))
	var cmd2 := _tc.build_command(_brawler)
	assert_true(cmd2.attack, "Выстрел произошел по отпусканию пальца 1")
	assert_almost_eq(cmd2.attack_aim.x, 0.0, 0.001)
	assert_almost_eq(cmd2.attack_aim.y, _data.attack.range_tiles, 0.001)
	assert_lt(cmd2.move.x, 0.0, "Бег продолжается во время выстрела")

	# Отпускаем палец 0
	_tc.simulate_touch_up(0, move_pos)
	var cmd3 := _tc.build_command(_brawler)
	assert_eq(cmd3.move, Vector2.ZERO, "Бег прекратился")


func test_camera_rotation_transforms_aim() -> void:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	# Поворачиваем камеру на -90 градусов по Y (взгляд направлен в сторону +X карты)
	cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	_tc.camera = cam

	# Тянем джойстик атаки вверх на экране (Vector2(0, -1))
	var center := _tc.get_attack_center()
	var drag_up := center + Vector2(0.0, -_tc.get_attack_radius() * 0.5)

	_tc.simulate_touch_down(0, center)
	_tc.simulate_drag(0, drag_up)
	_tc.simulate_touch_up(0, drag_up)

	var cmd := _tc.build_command(_brawler)
	assert_true(cmd.attack)
	# При повороте камеры на 90° вправо взгляд камеры "вперёд" (вверх на экране) направлен вдоль +X карты
	assert_almost_eq(cmd.attack_aim.y, 0.0, 0.01)
	assert_gt(cmd.attack_aim.x, 0.0, "Направление должно учитывать поворот камеры")
