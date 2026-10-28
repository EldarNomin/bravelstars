extends GutTest
## Стартовые герои (C-09) и столп «дуэль дольше одного магазина».

const HEROES: Array[String] = ["lynx", "anvil", "shishka"]

var w: SimWorld


func _hero(id: String) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id)


func _world() -> SimWorld:
	return SimWorld.new(SimFixtures.open_map(30, 30), 1)


## Урон полного магазина в идеальных условиях (все снаряды попали).
func _magazine_damage(d: BrawlerData) -> int:
	return d.max_ammo * d.attack.damage * maxi(1, d.attack.projectile_count)


func _hits_to_super(d: BrawlerData) -> int:
	return ceili(float(SimConstants.SUPER_CHARGE_MAX) / d.attack.super_charge_per_hit)


func test_all_load_with_ids() -> void:
	for id in HEROES:
		var d := _hero(id)
		assert_not_null(d, id)
		assert_eq(String(d.id), id)
		assert_true(d.has_super(), "%s: есть супер" % id)


func test_pillar_magazine_does_not_kill_same_class() -> void:
	for id in HEROES:
		var d := _hero(id)
		var mag := _magazine_damage(d)
		assert_lt(mag, d.max_hp, "%s: магазин %d < HP %d" % [id, mag, d.max_hp])
		assert_gt(mag, d.max_hp * 0.8, "%s: но магазин всё же опасен (>80%% HP)" % id)


func test_lynx_shot_and_pierce_super() -> void:
	w = _world()
	var me := w.add_brawler(_hero("lynx"), 0, Vector2(2.5, 10.5))
	var a := w.add_brawler(_hero("anvil"), 1, Vector2(9.5, 10.5))
	var b := w.add_brawler(_hero("anvil"), 1, Vector2(11.5, 10.5))
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(a.hp, 5600 - 820)
	assert_eq(b.hp, 5600, "обычный выстрел не пробивает")
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(a.hp, 5600 - 820 - 1800)
	assert_eq(b.hp, 5600 - 1800, "супер пробивает")
	assert_eq(_hits_to_super(me.data), 3)


func test_anvil_point_blank_and_charge() -> void:
	w = _world()
	var me := w.add_brawler(_hero("anvil"), 0, Vector2(5.5, 10.5))
	var target := w.add_brawler(_hero("lynx"), 1, Vector2(6.9, 10.5))
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 10)
	assert_eq(target.hp, 2600 - 5 * 330, "в упор все 5 дробин")
	assert_eq(me.super_charge, 5 * 50)
	assert_eq(_hits_to_super(me.data), 20, "4 полных залпа")


func test_anvil_ram_breaks_walls_and_knocks_back() -> void:
	w = _world()
	var me := w.add_brawler(_hero("anvil"), 0, Vector2(5.5, 10.5))
	var target := w.add_brawler(_hero("lynx"), 1, Vector2(8.5, 10.5))
	w.map.set_tile(7, 10, SimMap.Tile.WALL)
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.RIGHT))
	SimFixtures.run(w, 20)
	assert_eq(w.map.get_tile(7, 10), SimMap.Tile.FLOOR, "стена проломлена")
	assert_gt(me.pos.x, 8.0, "таран прошёл сквозь пролом")
	assert_eq(target.hp, 2600 - 1200)
	assert_gt(target.pos.x, 9.0, "цель отброшена")


func test_anvil_ram_stops_on_death() -> void:
	w = _world()
	var me := w.add_brawler(_hero("anvil"), 0, Vector2(5.5, 10.5))
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2.UP))
	w.step()
	w.damage(me, 99999, null, null, false, me.pos)
	SimFixtures.run(w, w.secs(w.balance.respawn_time) + 10)
	assert_true(me.alive)
	assert_eq(me.pos, me.spawn_pos)


func test_shishka_lobs_over_wall_with_min_range() -> void:
	w = _world()
	var me := w.add_brawler(_hero("shishka"), 0, Vector2(5.5, 10.5))
	var target := w.add_brawler(_hero("lynx"), 1, Vector2(10.5, 10.5))
	w.map.set_tile(7, 10, SimMap.Tile.HARD_WALL)
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, Vector2(5, 0)))
	SimFixtures.run(w, 25)
	assert_eq(target.hp, 2600 - 750)
	assert_eq(me.super_charge, 250)
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, true, Vector2(0.3, 0)))
	w.step()
	var p: SimProjectile = w.projectiles[0]
	assert_almost_eq(p.target.distance_to(me.pos), 2.0, 0.01, "не ближе 2 клеток")


func test_shishka_super_breaks_cover() -> void:
	w = _world()
	var me := w.add_brawler(_hero("shishka"), 0, Vector2(5.5, 10.5))
	w.map.set_tile(10, 10, SimMap.Tile.WALL)
	w.map.set_tile(11, 10, SimMap.Tile.WALL)
	me.super_charge = SimConstants.SUPER_CHARGE_MAX
	w.set_input(me.id, InputCommand.create(Vector2.ZERO, false, Vector2.ZERO, true, Vector2(5.5, 0)))
	SimFixtures.run(w, 30)
	assert_eq(w.map.get_tile(10, 10), SimMap.Tile.FLOOR)
	assert_eq(w.map.get_tile(11, 10), SimMap.Tile.FLOOR)
