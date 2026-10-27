class_name BenchWorkload
extends RefCounted
## Один сценарий для графического и headless-прогона.

const MAP_PATH: String = "res://data/maps/_debug_arena.json"
const HERO_PATHS: Array[String] = [
	"res://data/brawlers/lynx.tres",
	"res://data/brawlers/anvil.tres",
	"res://data/brawlers/shishka.tres",
]
const ROWS: Array[float] = [2.5, 6.5, 9.5]

var world: SimWorld
var step_count: int = 0
var step_total_us: int = 0
var step_max_us: int = 0
var projectile_total: int = 0
var projectile_max: int = 0


func setup() -> bool:
	var arena := SimMap.load_json(MAP_PATH)
	if arena == null or not arena.errors.is_empty():
		push_error("Benchmark map is missing or invalid")
		return false
	world = SimWorld.new(arena, 12)
	for team in 2:
		for index in HERO_PATHS.size():
			var source := load(HERO_PATHS[index]) as BrawlerData
			if source == null or source.attack == null:
				push_error("Benchmark hero is missing: " + HERO_PATHS[index])
				return false
			# Copy resources: accelerated firing is only for this reproducible stress scenario.
			var hero := source.duplicate(true) as BrawlerData
			hero.reload_time = 0.1
			hero.attack_cooldown = 0.1
			var x := 3.5 if team == 0 else 21.5
			world.add_brawler(hero, team, Vector2(x, ROWS[index]))
	return true


func step() -> void:
	for hero in world.brawlers:
		var direction := 1.0 if hero.team == 0 else -1.0
		world.set_input(hero.id, InputCommand.create(Vector2.ZERO, true, Vector2(7.0 * direction, 0)))
	var start_us := Time.get_ticks_usec()
	world.step()
	var duration_us := Time.get_ticks_usec() - start_us
	step_count += 1
	step_total_us += duration_us
	step_max_us = maxi(step_max_us, duration_us)
	projectile_total += world.projectiles.size()
	projectile_max = maxi(projectile_max, world.projectiles.size())
	world.drain_events()


func results() -> Dictionary:
	return {
		"ticks": step_count,
		"sim_avg_ms": float(step_total_us) / maxi(step_count, 1) / 1000.0,
		"sim_max_ms": float(step_max_us) / 1000.0,
		"projectiles_avg": float(projectile_total) / maxi(step_count, 1),
		"projectiles_max": projectile_max,
	}
