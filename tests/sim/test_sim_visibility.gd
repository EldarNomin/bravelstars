extends GutTest

var w: SimWorld
var me: SimBrawler
var hider: SimBrawler


func before_each() -> void:
	var m := SimMap.from_lines(PackedStringArray(["..........", ".......***", ".......***"]))
	w = SimWorld.new(m)
	me = w.add_brawler(SimFixtures.brawler(), 0, Vector2(1.5, 1.5))
	hider = w.add_brawler(SimFixtures.brawler(), 1, Vector2(8.5, 1.5))


func test_hidden_in_bush() -> void:
	assert_false(w.is_visible_to(0, hider))
	assert_true(w.is_visible_to(1, hider), "своим видно всегда")


func test_visible_outside_bush() -> void:
	hider.pos = Vector2(5.5, 0.5)
	assert_true(w.is_visible_to(0, hider))


func test_revealed_when_close() -> void:
	me.pos = Vector2(7.0, 1.5)
	assert_true(w.is_visible_to(0, hider))


func test_revealed_after_shooting() -> void:
	w.set_input(hider.id, InputCommand.create(Vector2.ZERO, true, Vector2.LEFT))
	w.step()
	assert_true(w.is_visible_to(0, hider))
	SimFixtures.run(w, w.secs(w.balance.reveal_after_attack))
	assert_false(w.is_visible_to(0, hider))


func test_autoaim_ignores_hidden() -> void:
	me.pos = Vector2(4.5, 1.5)
	assert_eq(w.autoaim_vector(me, 6.0), Vector2.ZERO)
