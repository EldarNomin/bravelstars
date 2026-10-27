class_name SimConstants
extends RefCounted
## Константы симуляции. Время внутри симуляции — только в тиках.

const TICK_RATE: int = 30
const DT: float = 1.0 / TICK_RATE

## Задержка перед регенерацией после урона или атаки.
const REGEN_DELAY: float = 3.0
## Доля max_hp, восстанавливаемая раз в секунду.
const REGEN_PERCENT: float = 0.13
const RESPAWN_TIME: float = 3.0

## С какого расстояния враг видит героя в кусте.
const BUSH_REVEAL_DISTANCE: float = 2.0
## Сколько герой виден из куста после выстрела или попадания по нему.
const REVEAL_AFTER_ACTION: float = 1.0

## Заряд супера хранится целым числом: супер готов при SUPER_CHARGE_MAX.
const SUPER_CHARGE_MAX: int = 1000

## Максимальный шаг перемещения за одну итерацию коллизий.
const MAX_MOVE_STEP: float = 0.25


static func ticks(seconds: float) -> int:
	return roundi(seconds * TICK_RATE)
