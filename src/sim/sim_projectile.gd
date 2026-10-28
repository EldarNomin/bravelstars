class_name SimProjectile
extends RefCounted
## Снаряд. STRAIGHT летит по направлению dir, LOB — по дуге от start к target за flight_ticks.

var id: int = 0
var owner_id: int = 0
var team: int = 0
var attack: AttackData
var is_super: bool = false
var pos: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var traveled: float = 0.0
var hit_ids: Array[int] = []
## Номер выстрела: у всех снарядов одного выстрела (дробь) он общий.
var attack_id: int = 0

var start: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var flight_ticks: int = 0
var age_ticks: int = 0
var dead: bool = false


## 0..1 — прогресс полёта навесного снаряда (для высоты дуги в отображении).
func lob_progress() -> float:
	if flight_ticks <= 0:
		return 1.0
	return clampf(float(age_ticks) / flight_ticks, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner": owner_id,
		"team": team,
		"kind": attack.kind,
		"super": is_super,
		"pos": pos,
		"dir": dir,
		"age": age_ticks,
		"target": target,
	}
