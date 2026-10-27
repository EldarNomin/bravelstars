extends GutTest
## Один и тот же seed и одни и те же команды обязаны давать одинаковое состояние —
## на этом держится сверка клиента с сервером в фазе 3.


func _simulate(seed_value: int) -> int:
	var w := SimWorld.new(SimMap.load_json("res://data/maps/_debug_arena.json"), seed_value)
	var ids: Array[int] = []
	for i in 6:
		ids.append(w.add_brawler(SimFixtures.brawler(), i % 2).id)
	var input_rng := RandomNumberGenerator.new()
	input_rng.seed = 42
	for _t in 600:
		for id in ids:
			var mv := Vector2(input_rng.randf_range(-1, 1), input_rng.randf_range(-1, 1))
			var aim := Vector2(input_rng.randf_range(-5, 5), input_rng.randf_range(-5, 5))
			w.set_input(id, InputCommand.create(mv, input_rng.randf() < 0.2, aim, input_rng.randf() < 0.05, aim))
		w.step()
	return w.state_hash()


func test_same_inputs_same_state() -> void:
	assert_eq(_simulate(7), _simulate(7))
