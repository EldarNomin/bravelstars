extends GutTest

const BENCH_SCRIPT: GDScript = preload("res://tools/bench/bench.gd")


func test_scenario_keeps_six_heroes_and_projectile_load() -> void:
	var original := load("res://data/brawlers/anvil.tres") as BrawlerData
	var cooldown_before := original.attack_cooldown
	var workload := BenchWorkload.new()
	assert_true(workload.setup())
	assert_eq(workload.world.brawlers.size(), 6)
	for _i in 300:
		workload.step()
	var report := workload.results()
	assert_eq(report.ticks, 300)
	assert_between(report.projectiles_avg, 35.0, 60.0)
	assert_gt(report.projectiles_max, 40)
	assert_eq(original.attack_cooldown, cooldown_before, "benchmark must not change hero data")


func test_fps_one_percent_low_uses_slowest_frame_times() -> void:
	var samples: Array[float] = []
	for _i in 99:
		samples.append(1.0 / 60.0)
	samples.append(0.1)
	var result: Dictionary = BENCH_SCRIPT.fps_results(samples)
	assert_almost_eq(result.fps_avg, 100.0 / (99.0 / 60.0 + 0.1), 0.001)
	assert_almost_eq(result.fps_1_percent_low, 10.0, 0.001)
