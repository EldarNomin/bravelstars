class_name BotBrain
extends RefCounted
## ИИ одного бота. Каждый тик возвращает InputCommand — такой же, как от игрока.
## Видит только то, что видит его команда (SimWorld.is_visible_to), координаты скрытых врагов не читает.

enum State { ROAM, FIGHT, CHASE, RETREAT, OBJECTIVE }

const WAYPOINT_REACHED: float = 0.35
const REPATH_TICKS: int = 10
const STRAFE_SWITCH_TICKS: int = 25

var brawler_id: int
var profile: BotProfile
var state: State = State.ROAM

var _nav: BotNav
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _path: PackedVector2Array = PackedVector2Array()
var _path_goal: Vector2 = Vector2.INF
var _repath_at: int = 0
var _target_id: int = 0
## id врага -> {pos, tick, vel}
var _memory: Dictionary = {}
var _roam_goal: Vector2 = Vector2.INF
var _strafe_sign: float = 1.0
var _next_think: int = 0
## До этого тика бот обходит укрытие к цели, а не стрейфит (против дёрганья у углов).
var _reposition_until: int = 0


func _init(p_brawler_id: int, nav: BotNav, p_profile: BotProfile = null, seed_value: int = 0) -> void:
	brawler_id = p_brawler_id
	_nav = nav
	profile = p_profile if p_profile != null else BotProfile.new()
	_rng.seed = seed_value * 7919 + p_brawler_id


func think(world: SimWorld) -> InputCommand:
	var me := world.get_brawler(brawler_id)
	var cmd := InputCommand.new()
	if me == null or not me.alive:
		_path = PackedVector2Array()
		return cmd
	_perceive(world, me)
	var target := _pick_target(world, me)
	_target_id = target.id if target != null else 0
	if world.tick >= _next_think:
		_next_think = world.tick + profile.reaction_ticks
		_decide(world, me, target)
		if world.tick % STRAFE_SWITCH_TICKS == 0 and _rng.randf() < 0.5:
			_strafe_sign = -_strafe_sign
	cmd.move = _steer(world, me, target)
	if target != null:
		_combat(world, me, target, cmd)
	return cmd


# --- Восприятие ----------------------------------------------------------------


func _perceive(world: SimWorld, me: SimBrawler) -> void:
	for e in world.enemies_of(me):
		if e.alive and world.is_visible_to(me.team, e):
			var prev: Dictionary = _memory.get(e.id, {})
			var vel := Vector2.ZERO
			if not prev.is_empty() and world.tick - int(prev["tick"]) == 1:
				vel = (e.pos - (prev["pos"] as Vector2)) * SimConstants.TICK_RATE
			_memory[e.id] = {"pos": e.pos, "tick": world.tick, "vel": vel}
		elif not e.alive:
			_memory.erase(e.id)
	var forget := SimConstants.ticks(profile.memory_time)
	for id: int in _memory.keys():
		if world.tick - int(_memory[id]["tick"]) > forget:
			_memory.erase(id)


func _seen_now(world: SimWorld, id: int) -> bool:
	return _memory.has(id) and int(_memory[id]["tick"]) == world.tick


func _pick_target(world: SimWorld, me: SimBrawler) -> SimBrawler:
	var best: SimBrawler = null
	var best_score := INF
	for id: int in _memory.keys():
		var e := world.get_brawler(id)
		if e == null or not e.alive:
			continue
		var pos: Vector2 = _memory[id]["pos"]
		var score := me.pos.distance_to(pos) + 3.0 * float(e.hp) / e.data.max_hp
		if not _seen_now(world, id):
			score += 4.0
		if id == _target_id:
			score -= 1.5
		if score < best_score:
			best_score = score
			best = e
	return best


# --- Решения и движение ----------------------------------------------------------


func _decide(world: SimWorld, me: SimBrawler, target: SimBrawler) -> void:
	var low := float(me.hp) / me.data.max_hp < profile.retreat_hp
	if low and target != null:
		state = State.RETREAT
	elif target == null:
		state = State.ROAM
	elif _seen_now(world, target.id):
		state = State.FIGHT
	else:
		state = State.CHASE
	if state == State.ROAM and (_roam_goal == Vector2.INF or me.pos.distance_to(_roam_goal) < 1.0):
		_roam_goal = _pick_roam_goal(world, me)


func _steer(world: SimWorld, me: SimBrawler, target: SimBrawler) -> Vector2:
	var obj: Dictionary = world.mode.bot_objective(world, me) if world.mode != null else {}
	if not obj.is_empty() and (obj["urgent"] or target == null) and state != State.RETREAT:
		state = State.OBJECTIVE
		return _follow(world, me, obj["pos"])
	if state == State.OBJECTIVE:
		state = State.ROAM
	if target == null or (state == State.CHASE and not _memory.has(target.id)):
		if state != State.ROAM:
			state = State.ROAM
			_roam_goal = _pick_roam_goal(world, me)
	elif state == State.ROAM:
		state = State.CHASE
	match state:
		State.RETREAT:
			return _follow(world, me, _retreat_point(world, me, target))
		State.CHASE:
			return _follow(world, me, _memory[target.id]["pos"])
		State.FIGHT:
			return _fight_move(world, me, target)
	return _follow(world, me, _roam_goal)


func _fight_move(world: SimWorld, me: SimBrawler, target: SimBrawler) -> Vector2:
	var to_t := target.pos - me.pos
	var dist := to_t.length()
	var want := _attack_range(me) * profile.preferred_range
	if not _can_hit(world, me, target):
		_reposition_until = world.tick + 15
	if dist > want or world.tick < _reposition_until:
		return _follow(world, me, target.pos)
	var dir := to_t.normalized() if dist > 0.01 else Vector2.RIGHT
	var strafe := Vector2(-dir.y, dir.x) * _strafe_sign
	var back := -dir if dist < want * 0.6 else Vector2.ZERO
	var mv := (strafe * 0.8 + back).limit_length(1.0)
	# Не упираться в стену при стрейфе.
	if not _nav.is_walkable(world.map.cell_of(me.pos + mv * 0.7)):
		_strafe_sign = -_strafe_sign
		mv = (-strafe * 0.8 + back).limit_length(1.0)
	return mv


func _follow(world: SimWorld, me: SimBrawler, goal: Vector2) -> Vector2:
	if goal == Vector2.INF:
		return Vector2.ZERO
	if world.map.has_line_of_fire(me.pos, goal) and _straight_walkable(world, me.pos, goal):
		_path = PackedVector2Array()
		var d := goal - me.pos
		return d.normalized() if d.length() > 0.2 else Vector2.ZERO
	if _path.is_empty() or world.tick >= _repath_at or _path_goal.distance_to(goal) > 1.5:
		_path = _nav.path(me.pos, goal)
		_path_goal = goal
		_repath_at = world.tick + REPATH_TICKS
	while not _path.is_empty() and me.pos.distance_to(_path[0]) < WAYPOINT_REACHED:
		_path.remove_at(0)
	if _path.is_empty():
		return Vector2.ZERO
	return (_path[0] - me.pos).normalized()


func _straight_walkable(world: SimWorld, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.4))
	for i in range(1, steps + 1):
		if not _nav.is_walkable(world.map.cell_of(a.lerp(b, float(i) / steps))):
			return false
	return true


func _retreat_point(world: SimWorld, me: SimBrawler, target: SimBrawler) -> Vector2:
	var threat: Vector2 = _memory[target.id]["pos"] if _memory.has(target.id) else target.pos
	var away := (me.pos - threat).normalized()
	if away == Vector2.ZERO:
		away = Vector2.LEFT
	var best := me.spawn_pos
	var best_score := -INF
	for i in 8:
		var cand := me.pos + away.rotated((i - 3.5) * 0.35) * 4.0
		var cell := world.map.cell_of(cand)
		if not _nav.is_walkable(cell):
			continue
		var score := cand.distance_to(threat)
		if world.map.get_tile(cell.x, cell.y) == SimMap.Tile.BUSH:
			score += 4.0 * profile.bush_preference
		if score > best_score:
			best_score = score
			best = Vector2(cell) + Vector2(0.5, 0.5)
	return best


func _pick_roam_goal(world: SimWorld, me: SimBrawler) -> Vector2:
	var m := world.map
	var enemy_spawns: Array = []
	for team: int in m.spawns.keys():
		if team != me.team:
			enemy_spawns.append_array(m.spawns[team])
	var center := Vector2(m.width, m.height) * 0.5
	var base: Vector2 = center
	if not enemy_spawns.is_empty() and _rng.randf() < 0.5:
		base = center.lerp(enemy_spawns[_rng.randi() % enemy_spawns.size()], 0.5)
	for _i in 10:
		var p := base + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		var c := m.cell_of(p)
		if _nav.is_walkable(c):
			return Vector2(c) + Vector2(0.5, 0.5)
	return center


# --- Бой -----------------------------------------------------------------------


func _combat(world: SimWorld, me: SimBrawler, target: SimBrawler, cmd: InputCommand) -> void:
	if not _seen_now(world, target.id):
		return
	var dist := me.pos.distance_to(target.pos)
	var atk := me.data.attack
	if (
		atk != null and me.ammo > 0 and me.cooldown_ticks == 0
		and dist <= atk.range_tiles + target.data.radius * 0.5
		and _can_hit(world, me, target)
		and (state != State.RETREAT or dist < atk.range_tiles * 0.6)
	):
		cmd.attack = true
		cmd.attack_aim = _aim(me, target, atk)
	var sup := me.data.super_attack
	if me.super_ready() and sup != null and dist <= sup.range_tiles and _can_hit_with(world, me, target, sup):
		cmd.use_super = true
		cmd.super_aim = _aim(me, target, sup)


func _can_hit(world: SimWorld, me: SimBrawler, target: SimBrawler) -> bool:
	return _can_hit_with(world, me, target, me.data.attack)


func _can_hit_with(world: SimWorld, me: SimBrawler, target: SimBrawler, atk: AttackData) -> bool:
	if atk == null:
		return false
	if atk.kind == AttackData.Kind.LOB or atk.breaks_walls:
		return true
	return world.map.has_line_of_fire(me.pos, target.pos, atk.projectile_radius + 0.1)


## Прицел с упреждением и ошибкой, зависящими от skill.
func _aim(me: SimBrawler, target: SimBrawler, atk: AttackData) -> Vector2:
	var to_t := target.pos - me.pos
	var vel: Vector2 = _memory.get(target.id, {}).get("vel", Vector2.ZERO)
	var travel := atk.flight_time if atk.kind == AttackData.Kind.LOB else to_t.length() / maxf(atk.speed, 0.1)
	var lead := vel * travel * profile.skill
	var aim := to_t + lead
	var err := deg_to_rad(_rng.randf_range(-1.0, 1.0) * 14.0 * (1.0 - profile.skill))
	return aim.rotated(err)


func _attack_range(me: SimBrawler) -> float:
	return me.data.attack.range_tiles if me.data.attack != null else 3.0
