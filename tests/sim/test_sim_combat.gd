extends GutTest

var w: SimWorld
var me: SimBrawler
var enemy: SimBrawler


func before_each() -> void:
	w = SimWorld.new(SimFixtures.open_map(), 1)
	me = w.add_brawler(SimFixtures.brawler(), 0, Vector2(5.5, 10.5))
	enemy = w.add_brawler(SimFixtures.brawler(), 1, Vector2(9.5, 10.5))


func _shoot(aim: Vector2 = Vector2.ZERO) -> void:
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, aim))
	w.step()


func test_shot_hits_and_charges_super() -> void:
	_shoot(Vector2.RIGHT)
	assert_eq(me.ammo, 2)
	SimFixtures.run(w, 15)
	assert_eq(enemy.hp, 2000)
	assert_almost_eq(me.super_charge, 0.25, 0.001)


func test_autoaim_targets_enemy() -> void:
	enemy.pos = Vector2(5.5, 6.5)
	_shoot()
	SimFixtures.run(w, 15)
	assert_eq(enemy.hp, 2000)


func test_miss_out_of_range() -> void:
	enemy.pos = Vector2(15.5, 10.5)
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 30)
	assert_eq(enemy.hp, 3000)
	assert_eq(w.projectiles.size(), 0, "снаряд исчез на дальности")


func test_cooldown_and_ammo() -> void:
	for _i in 6:
		_shoot(Vector2.UP)
	assert_eq(me.ammo, 2, "кулдаун: за 6 тиков подряд — один выстрел")
	SimFixtures.run(w, 19, me, InputCommand.create(Vector2.ZERO, true, Vector2.UP))
	assert_eq(me.ammo, 0, "три выстрела за 25 тиков — патроны кончились")
	_shoot(Vector2.UP)
	assert_eq(me.ammo, 0, "без патронов не стреляет")


func test_reload() -> void:
	_shoot(Vector2.UP)
	SimFixtures.run(w, SimConstants.ticks(me.data.reload_time))
	assert_eq(me.ammo, 3)


func test_wall_blocks_projectile() -> void:
	w.map.set_tile(7, 10, SimMap.Tile.WALL)
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 20)
	assert_eq(enemy.hp, 3000)
	assert_eq(w.map.get_tile(7, 10), SimMap.Tile.WALL)


func test_super_breaks_walls() -> void:
	w.map.set_tile(7, 10, SimMap.Tile.WALL)
	me.data.super_attack.breaks_walls = true
	me.super_charge = 1.0
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(w.map.get_tile(7, 10), SimMap.Tile.FLOOR)
	assert_eq(enemy.hp, 1000)
	assert_eq(me.super_charge, 0.0, "супер не заряжает сам себя")


func test_super_needs_full_charge() -> void:
	me.super_charge = 0.75
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(enemy.hp, 3000)


func test_lob_flies_over_walls_area_damage() -> void:
	var lob := SimFixtures.straight_attack(800, 7.0)
	lob.kind = AttackData.Kind.LOB
	lob.area_radius = 1.0
	me.data.attack = lob
	w.map.set_tile(7, 10, SimMap.Tile.HARD_WALL)
	_shoot(Vector2(4, 0))
	SimFixtures.run(w, SimConstants.ticks(lob.flight_time) + 1)
	assert_eq(enemy.hp, 2200)


func test_shotgun_spread_multiple_hits() -> void:
	var sg := SimFixtures.straight_attack(300, 5.0)
	sg.projectile_count = 5
	sg.spread_deg = 20.0
	sg.super_charge_per_hit = 0.05
	me.data.attack = sg
	enemy.pos = Vector2(6.8, 10.5)
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 10)
	assert_eq(enemy.hp, 1500, "в упор попадают все 5 дробин")
	assert_almost_eq(me.super_charge, 0.25, 0.001)


func test_death_and_respawn() -> void:
	enemy.hp = 500
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 15)
	assert_false(enemy.alive)
	assert_eq(me.kills, 1)
	assert_eq(enemy.deaths, 1)
	SimFixtures.run(w, SimConstants.ticks(SimConstants.RESPAWN_TIME))
	assert_true(enemy.alive)
	assert_eq(enemy.hp, 3000)
	assert_eq(enemy.pos, enemy.spawn_pos)


func test_no_respawn_when_disabled() -> void:
	w.respawn_enabled = false
	enemy.hp = 500
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 200)
	assert_false(enemy.alive)


func test_regen_after_delay() -> void:
	enemy.hp = 1000
	enemy.last_damage_tick = w.tick
	SimFixtures.run(w, SimConstants.ticks(SimConstants.REGEN_DELAY))
	assert_eq(enemy.hp, 1000)
	SimFixtures.run(w, 1)
	assert_eq(enemy.hp, 1000 + ceili(3000 * SimConstants.REGEN_PERCENT))


func test_knockback_and_stun() -> void:
	me.data.attack.knockback = 2.0
	me.data.attack.stun_time = 0.5
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 15)
	assert_gt(enemy.pos.x, 10.5)
	assert_true(enemy.is_stunned())


func test_dash_super() -> void:
	me.data.super_ability = DashSuper
	me.ability = me.data.create_super_ability()
	me.super_charge = 1.0
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 15)
	assert_almost_eq(me.pos.x, 5.5 + DashSuper.DISTANCE, 0.01)
	assert_eq(enemy.hp, 1000, "задет рывком")
