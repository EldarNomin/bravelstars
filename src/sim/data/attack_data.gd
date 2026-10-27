class_name AttackData
extends Resource
## Описание атаки или супер-удара. Все расстояния — в клетках, скорости — клеток/с, время — в секундах.

enum Kind {
	STRAIGHT,  ## снаряды летят по прямой, стены их останавливают
	LOB,  ## бросок навесом через стены, урон по площади в точке падения
}

@export var kind: Kind = Kind.STRAIGHT
## Урон одного снаряда.
@export var damage: int = 500
## Количество снарядов за выстрел (дробовик — 5, снайпер — 1).
@export var projectile_count: int = 1
## Общий угол разброса снарядов, градусы.
@export var spread_deg: float = 0.0
@export var range_tiles: float = 7.0
## Только для STRAIGHT.
@export var speed: float = 12.0
@export var projectile_radius: float = 0.2
## Снаряд проходит сквозь врагов.
@export var pierce: bool = false
## Разрушает обычные стены и кусты на пути (или в радиусе взрыва для LOB).
@export var breaks_walls: bool = false
## Для LOB: радиус урона в точке падения.
@export var area_radius: float = 1.0
## Для LOB: время полёта.
@export var flight_time: float = 0.8
## Сколько очков заряда супера (из SimConstants.SUPER_CHARGE_MAX = 1000) даёт одно попадание снаряда.
## 250 = супер за 4 попадания. Для супер-удара игнорируется.
@export var super_charge_per_hit: int = 250
## Отбрасывание цели при попадании, клетки.
@export var knockback: float = 0.0
## Оглушение цели при попадании, секунды.
@export var stun_time: float = 0.0
