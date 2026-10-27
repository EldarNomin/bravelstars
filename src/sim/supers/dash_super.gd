class_name DashSuper
extends SuperAbility
## Рывок/таран. Параметры — из BrawlerData.super_attack:
##   range_tiles — длина рывка, damage — урон задетым, knockback/stun_time — эффекты,
##   breaks_walls — ломает стены и кусты на пути.
## Ввод блокируется на время рывка. Длительность фиксирована.

const DURATION: float = 0.3
const HIT_RADIUS: float = 0.9
const DEFAULT_DISTANCE: float = 4.0

var _dir: Vector2 = Vector2.ZERO
var _per_tick: float = 0.0
var _ticks_left: int = 0
var _hit: Array[int] = []


func activate(world: SimWorld, caster: SimBrawler, aim: Vector2) -> void:
	_dir = aim.normalized() if aim.length_squared() > 0.0001 else caster.facing
	var atk := caster.data.super_attack
	var distance := atk.range_tiles if atk != null else DEFAULT_DISTANCE
	_ticks_left = SimConstants.ticks(DURATION)
	_per_tick = distance / _ticks_left
	_hit.clear()
	caster.facing = _dir
	world.emit(SimEvents.DASH_START, {"brawler": caster.id, "dir": _dir})


func tick(world: SimWorld, caster: SimBrawler) -> void:
	if _ticks_left <= 0:
		return
	_ticks_left -= 1
	var atk := caster.data.super_attack
	if atk != null and atk.breaks_walls:
		_break_ahead(world, caster)
	world.move_with_collision(caster, _dir * _per_tick)
	for e in world.enemies_of(caster):
		if e.alive and not (e.id in _hit) and e.pos.distance_to(caster.pos) <= HIT_RADIUS:
			_hit.append(e.id)
			if atk != null:
				world.damage(e, atk.damage, caster, atk, true, caster.pos)


func reset() -> void:
	_ticks_left = 0
	_hit.clear()


func blocks_input() -> bool:
	return _ticks_left > 0


func _break_ahead(world: SimWorld, caster: SimBrawler) -> void:
	var r := caster.data.radius
	var perp := Vector2(-_dir.y, _dir.x)
	for off: float in [-r, 0.0, r]:
		var p := caster.pos + _dir * (r + _per_tick + 0.05) + perp * off
		world.destroy_tile(world.map.cell_of(p))
