extends Node3D

const RUN_SECONDS: float = 60.0
const HEADLESS_TICKS: int = 10000
const TILE_COLORS: Dictionary = {
	SimMap.Tile.WALL: Color(0.6, 0.4, 0.25),
	SimMap.Tile.HARD_WALL: Color(0.35, 0.35, 0.4),
	SimMap.Tile.BUSH: Color(0.2, 0.65, 0.25),
	SimMap.Tile.WATER: Color(0.2, 0.45, 0.85),
}
const TILE_HEIGHTS: Dictionary = {
	SimMap.Tile.WALL: 1.0, SimMap.Tile.HARD_WALL: 1.2,
	SimMap.Tile.BUSH: 0.7, SimMap.Tile.WATER: 0.05,
}
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.3, 0.3)]

var workload := BenchWorkload.new()
var frame_times: Array[float] = []
var projectile_nodes: Dictionary = {}
var materials: Dictionary = {}
var accumulator: float = 0.0
var started_us: int = 0
var last_frame_us: int = 0
var finished: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var hud: Label = $HUD/Info


func _ready() -> void:
	if not workload.setup():
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--bench-sim"):
		for _i in HEADLESS_TICKS:
			workload.step()
		print("BENCH_SIM ", JSON.stringify(workload.results()))
		get_tree().quit()
		return
	_build_scene()
	started_us = Time.get_ticks_usec()
	last_frame_us = started_us


func _process(_delta: float) -> void:
	if started_us == 0 or finished:
		return
	var now := Time.get_ticks_usec()
	var frame_seconds := float(now - last_frame_us) / 1000000.0
	frame_times.append(frame_seconds)
	last_frame_us = now
	accumulator += frame_seconds
	while accumulator >= SimConstants.DT:
		accumulator -= SimConstants.DT
		workload.step()
	_render_projectiles()
	var elapsed := float(now - started_us) / 1000000.0
	var sim := workload.results()
	hud.text = "BENCH  %02d / 60 s\nСнаряды: %d   тик: %.2f / %.2f мс\n" % [
		mini(int(elapsed), 60), workload.world.projectiles.size(), sim.sim_avg_ms, sim.sim_max_ms,
	]
	hud.text += "6 героев · ускоренная стрельба · без управления"
	if elapsed >= RUN_SECONDS:
		_finish(elapsed)


static func fps_results(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"fps_avg": 0.0, "fps_1_percent_low": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += sample
	var slow_count := maxi(1, ceili(sorted.size() * 0.01))
	var slow_total := 0.0
	for i in range(sorted.size() - slow_count, sorted.size()):
		slow_total += sorted[i]
	return {
		"fps_avg": float(sorted.size()) / maxf(total, 0.000001),
		"fps_1_percent_low": float(slow_count) / maxf(slow_total, 0.000001),
	}


func _finish(elapsed: float) -> void:
	finished = true
	var result := workload.results()
	result.merge(fps_results(frame_times))
	result["duration_seconds"] = elapsed
	result["frame_count"] = frame_times.size()
	result["platform"] = OS.get_name()
	result["device"] = OS.get_model_name()
	result["resolution"] = "%dx%d" % [get_viewport().size.x, get_viewport().size.y]
	var file := FileAccess.open("user://bench.json", FileAccess.WRITE)
	var saved := file != null
	if saved:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	else:
		push_error("Cannot write user://bench.json: %s" % FileAccess.get_open_error())
	print("BENCH_RESULT ", JSON.stringify(result))
	hud.text = "РЕЗУЛЬТАТ · %.1f с\nFPS: %.1f средний · %.1f 1%% low\n" % [
		elapsed, result.fps_avg, result.fps_1_percent_low,
	]
	hud.text += "Тик: %.3f / %.3f мс · снаряды: %.1f / %d\n" % [
		result.sim_avg_ms, result.sim_max_ms, result.projectiles_avg, result.projectiles_max,
	]
	hud.text += "bench.json сохранён" if saved else "Ошибка сохранения bench.json"


func _build_scene() -> void:
	var arena := workload.world.map
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(arena.width, arena.height)
	floor_node.mesh = plane
	floor_node.material_override = _material(Color(0.82, 0.76, 0.6))
	floor_node.position = Vector3(arena.width * 0.5, 0, arena.height * 0.5)
	add_child(floor_node)
	for y in arena.height:
		for x in arena.width:
			var tile := arena.get_tile(x, y)
			if not TILE_COLORS.has(tile):
				continue
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			var height: float = TILE_HEIGHTS[tile]
			mesh.size = Vector3(1, height, 1)
			box.mesh = mesh
			box.material_override = _material(TILE_COLORS[tile], tile == SimMap.Tile.BUSH)
			box.position = Vector3(x + 0.5, height * 0.5, y + 0.5)
			add_child(box)
	for hero in workload.world.brawlers:
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = hero.data.radius
		capsule.height = 1.2
		body.mesh = capsule
		body.material_override = _material(TEAM_COLORS[hero.team])
		body.position = Vector3(hero.pos.x, 0.6, hero.pos.y)
		add_child(body)
	camera.position = Vector3(arena.width * 0.5, 19.0, arena.height * 0.5 + 10.0)
	camera.look_at(Vector3(arena.width * 0.5, 0, arena.height * 0.5))


func _render_projectiles() -> void:
	var live: Dictionary = {}
	for projectile in workload.world.projectiles:
		live[projectile.id] = true
		var node: MeshInstance3D = projectile_nodes.get(projectile.id)
		if node == null:
			node = MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = projectile.attack.projectile_radius
			mesh.height = mesh.radius * 2.0
			node.mesh = mesh
			node.material_override = _material(TEAM_COLORS[projectile.team].lightened(0.4))
			projectile_nodes[projectile.id] = node
			add_child(node)
		var height := 0.5
		if projectile.attack.kind == AttackData.Kind.LOB:
			var t := projectile.lob_progress()
			height += 12.0 * t * (1.0 - t)
		node.position = Vector3(projectile.pos.x, height, projectile.pos.y)
	for id: int in projectile_nodes.keys():
		if not live.has(id):
			projectile_nodes[id].queue_free()
			projectile_nodes.erase(id)


func _material(color: Color, translucent: bool = false) -> StandardMaterial3D:
	var key := [color, translucent]
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		if translucent:
			material.albedo_color.a = 0.75
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materials[key] = material
	return materials[key]
