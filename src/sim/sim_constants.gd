class_name SimConstants
extends RefCounted
## Константы симуляции. Время внутри симуляции — только в тиках.

const TICK_RATE: int = 30
const DT: float = 1.0 / TICK_RATE

## Правила боя (реген, возрождение, кусты) — в GlobalBalance / data/balance/global.tres.

## Заряд супера хранится целым числом: супер готов при SUPER_CHARGE_MAX.
const SUPER_CHARGE_MAX: int = 1000

## Максимальный шаг перемещения за одну итерацию коллизий.
const MAX_MOVE_STEP: float = 0.25


static func ticks(seconds: float) -> int:
	return roundi(seconds * TICK_RATE)
