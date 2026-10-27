class_name GlobalBalance
extends Resource
## Общие правила боя. Экземпляр матча — data/balance/global.tres. Время в секундах, расстояния в клетках.

## Задержка перед регенерацией после урона или своей атаки.
@export var regen_delay: float = 3.0
## Доля max_hp в секунду; начисляется плавно каждый тик.
@export var regen_percent_per_sec: float = 0.13
@export var respawn_time: float = 4.0
## Неуязвимость после возрождения; снимается первой атакой.
@export var spawn_shield_time: float = 2.0
@export var keep_super_on_death: bool = true

## С какого расстояния враг видит героя в кусте.
@export var bush_reveal_distance: float = 2.0
## Сколько герой виден из куста после своего выстрела.
@export var reveal_after_attack: float = 1.5
## Сколько герой виден из куста после попадания по нему.
@export var reveal_after_hit: float = 1.0
## Через сколько отрастает сломанный куст (0 — не отрастает). Стены не отрастают.
@export var bush_regrow_time: float = 12.0

## За сколько отыгрывается отбрасывание (не мгновенный телепорт).
@export var knockback_duration: float = 0.15
