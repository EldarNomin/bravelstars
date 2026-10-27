extends GutTest
## Правила из GlobalBalance (C-14).

var w: SimWorld
var me: SimBrawler
var enemy: SimBrawler


func before_each() -> void:
	w = SimWorld.new(SimFixtures.open_map(), 1, load("res://data/balance/global.tres"))
	me = w.add_brawler(SimFixtures.brawler(), 0, Vector2(5.5, 10.5))
	enemy = w.add_brawler(SimFixtures.brawler(), 1, Vector2(9.5, 10.5))


func _kill_enemy() -> void:
	w.damage(enemy, 99999, me, null, false, me.pos)


func test_balance_file_loaded() -> void:
	assert_eq(w.balance.respawn_time, 4.0)
	assert_true(w.balance.keep_super_on_death)


func test_spawn_shield_blocks_damage_until_attack() -> void:
	_kill_enemy()
	SimFixtures.run(w, w.secs(w.balance.respawn_time) + 1)
	assert_true(enemy.alive)
	assert_true(enemy.has_shield(w.tick))
	w.damage(enemy, 500, me, null, false, me.pos)
	assert_eq(enemy.hp, 3000, "щит держит")
	w.set_input(enemy.id, InputCommand.create(Vector2.ZERO, true, Vector2.UP))
	w.step()
	assert_false(enemy.has_shield(w.tick), "выстрел снимает щит")
	w.damage(enemy, 500, me, null, false, me.pos)
	assert_eq(enemy.hp, 2500)


func test_shield_expires() -> void:
	_kill_enemy()
	SimFixtures.run(w, w.secs(w.balance.respawn_time + w.balance.spawn_shield_time) + 2)
	assert_false(enemy.has_shield(w.tick))


func test_super_kept_on_death() -> void:
	enemy.super_charge = 600
	_kill_enemy()
	SimFixtures.run(w, w.secs(w.balance.respawn_time) + 1)
	assert_eq(enemy.super_charge, 600)


func test_knockback_spread_over_ticks() -> void:
	me.data.attack.knockback = 1.5
	_shoot_right()
	var start := enemy.pos.x
	var xs: Array[float] = []
	for _i in 20:
		w.step()
		xs.append(enemy.pos.x)
	assert_almost_eq(xs[-1] - start, 1.5, 0.05, "отброшен на 1.5 клетки")
	var first_move := xs.filter(func(x: float) -> bool: return x > start)[0] as float
	assert_lt(first_move - start, 1.0, "не мгновенно")


func test_bush_regrows_wall_does_not() -> void:
	w.map.set_tile(3, 3, SimMap.Tile.BUSH)
	w.map.set_tile(4, 3, SimMap.Tile.WALL)
	w.destroy_tile(Vector2i(3, 3))
	w.destroy_tile(Vector2i(4, 3))
	SimFixtures.run(w, w.secs(w.balance.bush_regrow_time) + 1)
	assert_eq(w.map.get_tile(3, 3), SimMap.Tile.BUSH)
	assert_eq(w.map.get_tile(4, 3), SimMap.Tile.FLOOR)
	var types: Array = w.drain_events().map(func(e: Dictionary) -> StringName: return e["type"])
	assert_has(types, SimEvents.TILE_RESTORED)


func test_regen_is_smooth_and_silent() -> void:
	enemy.hp = 1000
	enemy.last_damage_tick = w.tick
	SimFixtures.run(w, w.secs(w.balance.regen_delay) + 3)
	assert_between(enemy.hp, 1001, 1100, "растёт по чуть-чуть каждый тик")
	for e in w.drain_events():
		assert_ne(e["type"], SimEvents.HEAL, "реген не спамит событиями")


func test_reveal_after_attack_longer_than_after_hit() -> void:
	assert_gt(w.balance.reveal_after_attack, w.balance.reveal_after_hit)


func _shoot_right() -> void:
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, Vector2.RIGHT))
	w.step()
