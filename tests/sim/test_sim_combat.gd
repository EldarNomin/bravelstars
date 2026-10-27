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
	assert_eq(me.super_charge, 250)


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
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(w.map.get_tile(7, 10), SimMap.Tile.FLOOR)
	assert_eq(enemy.hp, 1000)
	assert_eq(me.super_charge, 0, "супер не заряжает сам себя")


func test_super_needs_full_charge() -> void:
	me.super_charge = SimConstants.SUPER_CHARGE_MAX - 1
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
	sg.super_charge_per_hit = 50
	me.data.attack = sg
	enemy.pos = Vector2(6.8, 10.5)
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 10)
	assert_eq(enemy.hp, 1500, "в упор попадают все 5 дробин")
	assert_eq(me.super_charge, 250)


func test_death_and_respawn() -> void:
	enemy.hp = 500
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 15)
	assert_false(enemy.alive)
	assert_eq(me.kills, 1)
	assert_eq(enemy.deaths, 1)
	SimFixtures.run(w, w.secs(w.balance.respawn_time))
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
	SimFixtures.run(w, w.secs(w.balance.regen_delay))
	assert_eq(enemy.hp, 1000)
	SimFixtures.run(w, SimConstants.TICK_RATE)
	assert_almost_eq(enemy.hp, 1000 + roundi(3000 * w.balance.regen_percent_per_sec), 2, "за секунду ~13%")


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
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 15)
	assert_almost_eq(me.pos.x, 5.5 + DashSuper.DISTANCE, 0.01)
	assert_eq(enemy.hp, 1000, "задет рывком")


func _use_super(aim: Vector2) -> void:
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, aim))
	w.step()


func test_dash_stops_on_death() -> void:
	me.data.super_ability = DashSuper
	me.ability = me.data.create_super_ability()
	_use_super(Vector2.UP)
	w.damage(me, 99999, enemy, null, false, enemy.pos)
	SimFixtures.run(w, w.secs(w.balance.respawn_time) + 10)
	assert_true(me.alive)
	assert_eq(me.pos, me.spawn_pos, "после возрождения рывок не продолжается")
	assert_false(me.ability.blocks_input())


func test_super_charge_exact_threshold() -> void:
	me.data.attack.super_charge_per_hit = 100
	for _i in 9:
		w.damage(enemy, 1, me, me.data.attack, false, me.pos)
	assert_false(me.super_ready())
	w.damage(enemy, 1, me, me.data.attack, false, me.pos)
	assert_true(me.super_ready(), "10 попаданий по 100 = ровно супер")


func test_dead_owner_gets_no_charge() -> void:
	_shoot(Vector2.RIGHT)
	w.damage(me, 99999, enemy, null, false, enemy.pos)
	SimFixtures.run(w, 15)
	assert_eq(enemy.hp, 2000, "снаряд долетел")
	assert_eq(me.super_charge, 0)


func test_super_without_super_keeps_charge() -> void:
	me.data.super_attack = null
	_use_super(Vector2.RIGHT)
	assert_eq(me.super_charge, SimConstants.SUPER_CHARGE_MAX)


func test_stun_exact_duration() -> void:
	me.data.attack.stun_time = 0.5
	enemy.pos = Vector2(6.5, 10.5)
	_shoot(Vector2.RIGHT)
	var blocked := 0
	for _i in 30:
		if enemy.is_stunned():
			blocked += 1
		w.step()
	assert_eq(blocked, SimConstants.ticks(0.5))


func test_pierce_hits_all_in_line() -> void:
	me.data.attack.pierce = true
	var second := w.add_brawler(SimFixtures.brawler(), 1, Vector2(10.5, 10.5))
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 20)
	assert_eq(enemy.hp, 2000)
	assert_eq(second.hp, 2000)


func test_lob_super_breaks_walls_in_radius() -> void:
	var lob := SimFixtures.straight_attack(500, 7.0)
	lob.kind = AttackData.Kind.LOB
	lob.area_radius = 1.0
	lob.breaks_walls = true
	me.data.super_attack = lob
	w.map.set_tile(9, 5, SimMap.Tile.WALL)
	_use_super(Vector2(4, -5))
	SimFixtures.run(w, SimConstants.ticks(lob.flight_time) + 1)
	assert_eq(w.map.get_tile(9, 5), SimMap.Tile.FLOOR)


func test_events_survive_multiple_ticks() -> void:
	enemy.hp = 500
	_shoot(Vector2.RIGHT)
	SimFixtures.run(w, 15)
	var types: Array = w.drain_events().map(func(e: Dictionary) -> StringName: return e["type"])
	assert_has(types, SimEvents.ATTACK)
	assert_has(types, SimEvents.HIT)
	assert_has(types, SimEvents.DEATH)
	assert_eq(w.drain_events().size(), 0, "очередь очищена")


func test_regen_resets_on_attack() -> void:
	me.hp = 1000
	me.last_damage_tick = w.tick
	SimFixtures.run(w, w.secs(w.balance.regen_delay) - 5)
	_shoot(Vector2.UP)
	SimFixtures.run(w, 10)
	assert_eq(me.hp, 1000, "выстрел сбросил таймер регена")
