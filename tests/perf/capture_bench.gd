extends SceneTree
## Ручная проверка: снимок сцены и результата после полного минутного прогона.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/bench/bench.tscn") as PackedScene
	var bench := scene.instantiate()
	root.add_child(bench)
	current_scene = bench
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image().save_png("res://tests/perf/bench-scene.png")
	await create_timer(59.0).timeout
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image().save_png("res://tests/perf/bench-result.png")
	if first != OK or second != OK or not bench.get("finished"):
		push_error("Benchmark capture or full 60-second run failed")
		quit(1)
		return
	print("BENCH_CAPTURE scene and final result saved")
	quit()
