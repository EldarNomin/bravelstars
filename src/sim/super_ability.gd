class_name SuperAbility
extends RefCounted
## Суперспособность героя. По умолчанию стреляет атакой BrawlerData.super_attack.
## Для своих суперов наследуйтесь и переопределяйте activate(). Пример: src/sim/supers/dash_super.gd.
##
## Правила: только API SimWorld, никаких Input/Time/randf — см. AGENTS.md.


## Вызывается в тик, когда игрок применил супер (заряд уже списан).
func activate(world: SimWorld, caster: SimBrawler, aim: Vector2) -> void:
	if caster.data.super_attack != null:
		world.fire_attack(caster, caster.data.super_attack, aim, true)


## Вызывается каждый тик для всех живых героев — для длительных эффектов (щит, рывок).
func tick(_world: SimWorld, _caster: SimBrawler) -> void:
	pass


## Сброс состояния при смерти и возрождении. Наследники с полями обязаны его переопределить.
func reset() -> void:
	pass


## true — пока идёт эффект, ввод игрока (движение и атаки) игнорируется.
func blocks_input() -> bool:
	return false
