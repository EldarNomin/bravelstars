class_name DashSuper
extends SuperAbility
## Пример нестандартного супера: рывок на DISTANCE клеток за DURATION секунд,
## урон и отбрасывание всем врагам, которых задел. Ввод блокируется на время рывка.

const DISTANCE: float = 4.0
const DURATION: float = 0.3
const HIT_RADIUS: float = 0.9

var _dir: Vector2 = Vector2.ZERO
var _ticks_left: int = 0
var _hit: Array[int] = []


func activate(world: SimWorld, caster: SimBrawler, aim: Vector2) -> void:
	_dir = aim.normalized() if aim.length_squared() > 0.0001 else caster.facing
	_ticks_left = SimConstants.ticks(DURATION)
	_hit.clear()
	caster.facing = _dir
	world.events.append({"type": "dash_start", "brawler": caster.id, "dir": _dir})


func tick(world: SimWorld, caster: SimBrawler) -> void:
	if _ticks_left <= 0:
		return
	_ticks_left -= 1
	var per_tick := DISTANCE / SimConstants.ticks(DURATION)
	world.move_with_collision(caster, _dir * per_tick)
	var atk := caster.data.super_attack
	for e in world.enemies_of(caster):
		if e.alive and not (e.id in _hit) and e.pos.distance_to(caster.pos) <= HIT_RADIUS:
			_hit.append(e.id)
			if atk != null:
				world.damage(e, atk.damage, caster, atk, true, caster.pos)


func blocks_input() -> bool:
	return _ticks_left > 0
