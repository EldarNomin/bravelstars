class_name SimWorld
extends RefCounted
## Мир симуляции. Продвигается вызовом step() ровно TICK_RATE раз в секунду игрового времени.
##
## Поток данных: set_input() для каждого героя -> step() -> отображение читает brawlers,
## projectiles, map и events (события только этого тика).
## Ничего не знает про ввод, сцену и сеть — см. AGENTS.md.

var tick: int = 0
var map: SimMap
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var brawlers: Array[SimBrawler] = []
var projectiles: Array[SimProjectile] = []
## События текущего тика: {"type": "attack"|"hit"|"death"|"respawn"|"explosion"|"tile_destroyed"|
## "projectile_end"|"heal", ...}. Очищаются в начале step().
var events: Array[Dictionary] = []
## Режимы без возрождения (например «Выживание») ставят false.
var respawn_enabled: bool = true

var _inputs: Dictionary = {}
var _next_id: int = 1


func _init(p_map: SimMap, p_seed: int = 0) -> void:
	map = p_map
	rng.seed = p_seed


# --- Настройка --------------------------------------------------------------


func add_brawler(data: BrawlerData, team: int, at: Vector2 = Vector2.INF) -> SimBrawler:
	var p := at
	if p == Vector2.INF:
		p = _pick_spawn(team)
	var b := SimBrawler.new(_alloc_id(), team, data, p)
	brawlers.append(b)
	return b


func get_brawler(id: int) -> SimBrawler:
	for b in brawlers:
		if b.id == id:
			return b
	return null


## Команда действует только на следующий step().
func set_input(brawler_id: int, cmd: InputCommand) -> void:
	_inputs[brawler_id] = cmd


# --- Тик ----------------------------------------------------------------------


func step() -> void:
	events.clear()
	for b in brawlers:
		_apply_input(b, _inputs.get(b.id) as InputCommand)
	for b in brawlers:
		if b.alive:
			b.ability.tick(self, b)
	_update_projectiles()
	for b in brawlers:
		_update_timers(b)
	_inputs.clear()
	tick += 1


func _apply_input(b: SimBrawler, cmd: InputCommand) -> void:
	if cmd == null or not b.alive or b.is_stunned() or b.ability.blocks_input():
		return
	var mv := cmd.move.limit_length(1.0)
	if mv.length_squared() > 0.0001:
		move_with_collision(b, mv * b.data.move_speed * SimConstants.DT)
		b.facing = mv.normalized()
	if cmd.attack and b.ammo > 0 and b.cooldown_ticks == 0 and b.data.attack != null:
		b.ammo -= 1
		b.cooldown_ticks = SimConstants.ticks(b.data.attack_cooldown)
		b.last_attack_tick = tick
		fire_attack(b, b.data.attack, cmd.attack_aim, false)
	if cmd.use_super and b.super_ready():
		b.super_charge = 0.0
		b.last_attack_tick = tick
		b.ability.activate(self, b, cmd.super_aim)
		events.append({"type": "super", "brawler": b.id})


func _update_timers(b: SimBrawler) -> void:
	if not b.alive:
		if b.respawn_at_tick >= 0 and tick >= b.respawn_at_tick:
			b.reset_at(b.spawn_pos)
			events.append({"type": "respawn", "brawler": b.id})
		return
	if b.cooldown_ticks > 0:
		b.cooldown_ticks -= 1
	if b.stun_ticks > 0:
		b.stun_ticks -= 1
	if b.ammo < b.data.max_ammo:
		b.reload_progress += 1
		if b.reload_progress >= SimConstants.ticks(b.data.reload_time):
			b.ammo += 1
			b.reload_progress = 0
	else:
		b.reload_progress = 0
	var idle := tick - maxi(b.last_damage_tick, b.last_attack_tick)
	var delay := SimConstants.ticks(SimConstants.REGEN_DELAY)
	if b.hp < b.data.max_hp and idle >= delay and (idle - delay) % SimConstants.TICK_RATE == 0:
		heal(b, ceili(b.data.max_hp * SimConstants.REGEN_PERCENT))


# --- API для способностей, режимов и ботов -------------------------------------


## Перемещает героя с учётом стен и воды (шагами, чтобы не проскакивать сквозь стены).
func move_with_collision(b: SimBrawler, delta: Vector2) -> void:
	var steps := maxi(1, ceili(delta.length() / SimConstants.MAX_MOVE_STEP))
	var seg := delta / steps
	for _i in steps:
		b.pos = map.resolve_circle(b.pos + seg, b.data.radius)


## Выпускает атаку. aim — вектор в клетках от героя; нулевой — автоприцел.
func fire_attack(caster: SimBrawler, attack: AttackData, aim: Vector2, is_super: bool) -> void:
	var aim_vec := aim
	if aim_vec.length_squared() < 0.0001:
		aim_vec = autoaim_vector(caster, attack.range_tiles)
	var dir := caster.facing
	if aim_vec.length_squared() > 0.0001:
		dir = aim_vec.normalized()
	caster.facing = dir
	caster.reveal_until_tick = tick + SimConstants.ticks(SimConstants.REVEAL_AFTER_ACTION)
	var n := maxi(1, attack.projectile_count)
	for i in n:
		var angle := 0.0
		if n > 1:
			angle = deg_to_rad(-attack.spread_deg * 0.5 + attack.spread_deg * i / (n - 1))
		var p := SimProjectile.new()
		p.id = _alloc_id()
		p.owner_id = caster.id
		p.team = caster.team
		p.attack = attack
		p.is_super = is_super
		p.pos = caster.pos
		p.start = caster.pos
		p.dir = dir.rotated(angle)
		if attack.kind == AttackData.Kind.LOB:
			var dist := attack.range_tiles
			if aim_vec.length_squared() > 0.0001:
				dist = minf(aim_vec.length(), attack.range_tiles)
			p.target = caster.pos + p.dir * dist
			p.flight_ticks = maxi(1, SimConstants.ticks(attack.flight_time))
		projectiles.append(p)
	events.append({"type": "attack", "brawler": caster.id, "super": is_super, "dir": dir})


## Вектор на ближайшего видимого врага в радиусе, или ноль.
func autoaim_vector(caster: SimBrawler, max_range: float) -> Vector2:
	var best: SimBrawler = null
	var best_d := INF
	for e in brawlers:
		if e.team == caster.team or not e.alive or not is_visible_to(caster.team, e):
			continue
		var d := caster.pos.distance_to(e.pos)
		if d <= max_range + e.data.radius and d < best_d:
			best_d = d
			best = e
	if best == null:
		return Vector2.ZERO
	return best.pos - caster.pos


func damage(
	target: SimBrawler, amount: int, source: SimBrawler, attack: AttackData, is_super: bool, from: Vector2
) -> void:
	if not target.alive:
		return
	target.hp -= amount
	target.last_damage_tick = tick
	target.reveal_until_tick = tick + SimConstants.ticks(SimConstants.REVEAL_AFTER_ACTION)
	if source != null and attack != null and not is_super:
		source.super_charge = minf(1.0, source.super_charge + attack.super_charge_per_hit)
	events.append({
		"type": "hit", "target": target.id, "source": source.id if source else 0,
		"amount": amount, "super": is_super,
	})
	if target.hp <= 0:
		_kill(target, source)
		return
	if attack != null:
		if attack.knockback > 0.0:
			var away := (target.pos - from).normalized()
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			move_with_collision(target, away * attack.knockback)
		if attack.stun_time > 0.0:
			target.stun_ticks = maxi(target.stun_ticks, SimConstants.ticks(attack.stun_time))


func heal(target: SimBrawler, amount: int) -> void:
	if not target.alive or target.hp >= target.data.max_hp:
		return
	var before := target.hp
	target.hp = mini(target.data.max_hp, target.hp + amount)
	events.append({"type": "heal", "target": target.id, "amount": target.hp - before})


## Разрушает стену или куст. Непробиваемые стены и вода не разрушаются.
func destroy_tile(cell: Vector2i) -> void:
	var t := map.get_tile(cell.x, cell.y)
	if t == SimMap.Tile.WALL or t == SimMap.Tile.BUSH:
		map.set_tile(cell.x, cell.y, SimMap.Tile.FLOOR)
		events.append({"type": "tile_destroyed", "cell": cell, "tile": t})


## Видит ли команда viewer_team героя b (кусты). Боты обязаны пользоваться этим, а не читать pos напрямую.
func is_visible_to(viewer_team: int, b: SimBrawler) -> bool:
	if b.team == viewer_team:
		return true
	if not b.alive:
		return false
	if not map.is_bush_at(b.pos):
		return true
	if tick < b.reveal_until_tick:
		return true
	for v in brawlers:
		if v.team == viewer_team and v.alive:
			if v.pos.distance_to(b.pos) <= SimConstants.BUSH_REVEAL_DISTANCE:
				return true
	return false


func enemies_of(b: SimBrawler) -> Array[SimBrawler]:
	var out: Array[SimBrawler] = []
	for e in brawlers:
		if e.team != b.team:
			out.append(e)
	return out


# --- Снаряды ------------------------------------------------------------------


func _update_projectiles() -> void:
	for p in projectiles:
		if p.dead:
			continue
		p.age_ticks += 1
		if p.attack.kind == AttackData.Kind.LOB:
			_update_lob(p)
		else:
			_update_straight(p)
		if p.dead:
			events.append({"type": "projectile_end", "projectile": p.id, "pos": p.pos})
	projectiles = projectiles.filter(func(p: SimProjectile) -> bool: return not p.dead)


func _update_straight(p: SimProjectile) -> void:
	var a := p.attack
	var remaining := minf(a.speed * SimConstants.DT, a.range_tiles - p.traveled)
	var steps := maxi(1, ceili(remaining / 0.2))
	var seg := remaining / steps
	for _i in steps:
		var prev := p.pos
		p.pos += p.dir * seg
		p.traveled += seg
		var cell := map.cell_of(p.pos)
		var t := map.get_tile(cell.x, cell.y)
		if a.breaks_walls and (t == SimMap.Tile.WALL or t == SimMap.Tile.BUSH):
			destroy_tile(cell)
		elif SimMap.blocks_projectiles(t):
			p.dead = true
			return
		var owner := get_brawler(p.owner_id)
		for b in brawlers:
			if b.team == p.team or not b.alive or b.id in p.hit_ids:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(b.pos, prev, p.pos)
			if closest.distance_to(b.pos) <= b.data.radius + a.projectile_radius:
				p.hit_ids.append(b.id)
				damage(b, a.damage, owner, a, p.is_super, prev)
				if not a.pierce:
					p.dead = true
					return
	if p.traveled >= a.range_tiles - 0.0001:
		p.dead = true


func _update_lob(p: SimProjectile) -> void:
	p.pos = p.start.lerp(p.target, p.lob_progress())
	if p.age_ticks < p.flight_ticks:
		return
	var a := p.attack
	var owner := get_brawler(p.owner_id)
	for b in brawlers:
		if b.team == p.team or not b.alive:
			continue
		if b.pos.distance_to(p.target) <= a.area_radius + b.data.radius:
			damage(b, a.damage, owner, a, p.is_super, p.target)
	if a.breaks_walls:
		var r := ceili(a.area_radius)
		var c := map.cell_of(p.target)
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(p.target) <= a.area_radius:
					destroy_tile(Vector2i(x, y))
	events.append({"type": "explosion", "pos": p.target, "radius": a.area_radius, "super": p.is_super})
	p.dead = true


# --- Служебное ----------------------------------------------------------------


func _kill(target: SimBrawler, killer: SimBrawler) -> void:
	target.alive = false
	target.hp = 0
	target.deaths += 1
	target.super_charge = 0.0
	if killer != null and killer != target:
		killer.kills += 1
	if respawn_enabled:
		target.respawn_at_tick = tick + SimConstants.ticks(SimConstants.RESPAWN_TIME)
	events.append({"type": "death", "target": target.id, "killer": killer.id if killer else 0})


func _pick_spawn(team: int) -> Vector2:
	var points: Array = map.spawns.get(team, [])
	if points.is_empty():
		return Vector2(map.width * 0.5, map.height * 0.5)
	var count := 0
	for b in brawlers:
		if b.team == team:
			count += 1
	return points[count % points.size()]


func _alloc_id() -> int:
	_next_id += 1
	return _next_id - 1


func snapshot() -> Dictionary:
	var bs: Array = []
	for b in brawlers:
		bs.append(b.to_dict())
	var ps: Array = []
	for p in projectiles:
		ps.append(p.to_dict())
	return {"tick": tick, "brawlers": bs, "projectiles": ps, "tiles": map.tiles}


## Хэш состояния — для тестов детерминированности и сверки клиент/сервер.
func state_hash() -> int:
	return hash(var_to_str(snapshot()))
