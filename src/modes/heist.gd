class_name Heist
extends GameMode
## «Добыча»: шахта в центре (метка 'G') раз в SHARD_INTERVAL секунд выдаёт осколок.
## Осколок надо донести до своего сейфа (метка 'A' — команда 1, 'B' — команда 2).
## Несущий медленнее и виден в кустах; при смерти роняет всё. Победа — target_score
## сданных осколков, иначе лидер по времени.

const SHARD_INTERVAL: float = 7.0
const PICKUP_RADIUS: float = 0.7
const SAFE_RADIUS: float = 1.5
const CARRIER_SLOWDOWN: float = 0.85
const SAFE_MARKERS: Array[String] = ["A", "B"]

var target_score: int = 12
## Осколки на земле.
var shards: Array[Vector2] = []
var mine: Vector2 = Vector2.INF
## Команда -> позиция сейфа.
var safes: Dictionary = {}

var _next_shard_tick: int = 0


func _init(p_target: int = 12, duration_sec: float = 150.0, countdown_sec: float = 3.0) -> void:
	target_score = p_target
	duration_ticks = SimConstants.ticks(duration_sec)
	countdown_ticks = SimConstants.ticks(countdown_sec)
	scores = {0: 0, 1: 0}


## Вызвать после создания мира (берёт метки с карты).
func setup(world: SimWorld) -> void:
	var m := world.map
	var g: Array = m.markers.get("G", [])
	mine = g[0] if not g.is_empty() else Vector2(m.width, m.height) * 0.5
	for team in SAFE_MARKERS.size():
		var pts: Array = m.markers.get(SAFE_MARKERS[team], [])
		safes[team] = pts[0] if not pts.is_empty() else (m.spawns.get(team, [mine])[0] as Vector2)
	_next_shard_tick = countdown_ticks


static func carried(b: SimBrawler) -> int:
	return int(b.mode_data.get("shards", 0))


func on_playing_tick(world: SimWorld) -> void:
	if world.tick >= _next_shard_tick:
		_next_shard_tick = world.tick + SimConstants.ticks(SHARD_INTERVAL)
		var p := mine + Vector2(world.rng.randf_range(-0.6, 0.6), world.rng.randf_range(-0.6, 0.6))
		shards.append(p)
		world.emit(SimEvents.PICKUP_SPAWNED, {"pos": p, "kind": &"shard"})
	for b in world.brawlers:
		if not b.alive:
			continue
		_pick_up(world, b)
		_deposit(world, b)
		var n := carried(b)
		b.speed_mult = CARRIER_SLOWDOWN if n > 0 else 1.0
		b.force_visible = n > 0


func _pick_up(world: SimWorld, b: SimBrawler) -> void:
	var i := 0
	while i < shards.size():
		if shards[i].distance_to(b.pos) <= PICKUP_RADIUS + b.data.radius:
			b.mode_data["shards"] = carried(b) + 1
			world.emit(SimEvents.PICKUP_TAKEN, {"brawler": b.id, "pos": shards[i], "kind": &"shard"})
			shards.remove_at(i)
		else:
			i += 1


func _deposit(world: SimWorld, b: SimBrawler) -> void:
	var n := carried(b)
	if n == 0 or b.pos.distance_to(safes[b.team]) > SAFE_RADIUS:
		return
	b.mode_data["shards"] = 0
	world.emit(SimEvents.DEPOSIT, {"brawler": b.id, "team": b.team, "amount": n})
	add_score(world, b.team, n)
	if scores[b.team] >= target_score:
		finish(world, b.team, "score")


func on_kill(world: SimWorld, victim: SimBrawler, _killer: SimBrawler) -> void:
	var n := carried(victim)
	victim.mode_data["shards"] = 0
	victim.speed_mult = 1.0
	victim.force_visible = false
	for i in n:
		var a := TAU * i / maxi(n, 1)
		var p := world.map.resolve_circle(victim.pos + Vector2.from_angle(a) * 0.5, 0.2)
		shards.append(p)
		world.emit(SimEvents.PICKUP_SPAWNED, {"pos": p, "kind": &"shard"})


func bot_objective(_world: SimWorld, b: SimBrawler) -> Dictionary:
	var n := carried(b)
	# С добычей — домой; чем больше несёт, тем важнее.
	if n >= 2 or (n > 0 and float(b.hp) / b.data.max_hp < 0.5):
		return {"pos": safes[b.team], "urgent": true}
	# Ближайший осколок на земле.
	var best := Vector2.INF
	for s in shards:
		if best == Vector2.INF or b.pos.distance_to(s) < b.pos.distance_to(best):
			best = s
	if best != Vector2.INF:
		return {"pos": best, "urgent": b.pos.distance_to(best) < 4.0}
	if n > 0:
		return {"pos": safes[b.team], "urgent": false}
	return {"pos": mine, "urgent": false}
