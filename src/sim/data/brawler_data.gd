class_name BrawlerData
extends Resource
## Описание героя. Экземпляры лежат в data/brawlers/*.tres. Шаблон — docs/templates/brawler.md.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
@export var max_hp: int = 3200
## Клеток в секунду. Обычная скорость ~2.4, быстрый герой ~2.9.
@export var move_speed: float = 2.4
@export var radius: float = 0.4

@export_group("Attack")
@export var max_ammo: int = 3
## Секунд на восстановление одного заряда.
@export var reload_time: float = 1.4
## Минимальная пауза между выстрелами.
@export var attack_cooldown: float = 0.4
@export var attack: AttackData

@export_group("Super")
## Используется стандартной суперспособностью (просто стреляет этой атакой).
@export var super_attack: AttackData
## Необязательный скрипт, наследник SuperAbility, для нестандартных суперов (рывок, щит, призыв...).
@export var super_ability: Script


## Ресурс общий для всех копий героя в матче — в симуляции его только читают, никогда не меняют.
func create_super_ability() -> SuperAbility:
	if super_ability != null:
		var ability := super_ability.new() as SuperAbility
		if ability == null:
			push_error("BrawlerData %s: super_ability должен наследовать SuperAbility" % id)
			return SuperAbility.new()
		return ability
	return SuperAbility.new()


## Есть ли у героя хоть какой-то супер (иначе заряд не тратится впустую).
func has_super() -> bool:
	return super_attack != null or super_ability != null
