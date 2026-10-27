class_name SimBrawler
extends RefCounted
## Состояние героя в симуляции.

var id: int = 0
var team: int = 0
var data: BrawlerData
var ability: SuperAbility

var pos: Vector2 = Vector2.ZERO
var spawn_pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var hp: int = 0
var alive: bool = true

var ammo: int = 0
var reload_progress: int = 0
var cooldown_ticks: int = 0
## 0..SimConstants.SUPER_CHARGE_MAX, супер доступен при максимуме.
var super_charge: int = 0

var stun_ticks: int = 0
var last_damage_tick: int = -100000
var last_attack_tick: int = -100000
var reveal_until_tick: int = -1
var respawn_at_tick: int = -1
## Неуязвим до этого тика (защита после возрождения).
var shield_until_tick: int = -1
var knock_step: Vector2 = Vector2.ZERO
var knock_ticks: int = 0
var regen_milli: int = 0

var kills: int = 0
var deaths: int = 0
## Поле для режимов (кристаллы, усилители и т.п.).
var mode_data: Dictionary = {}
## Режим может замедлить героя (например, несущего добычу) и сделать видимым в кустах.
var speed_mult: float = 1.0
var force_visible: bool = false


func _init(p_id: int, p_team: int, p_data: BrawlerData, p_pos: Vector2) -> void:
	id = p_id
	team = p_team
	data = p_data
	ability = p_data.create_super_ability()
	spawn_pos = p_pos
	reset_at(p_pos)


func reset_at(p: Vector2) -> void:
	pos = p
	hp = data.max_hp
	alive = true
	ammo = data.max_ammo
	reload_progress = 0
	cooldown_ticks = 0
	stun_ticks = 0
	respawn_at_tick = -1
	knock_ticks = 0
	regen_milli = 0
	if ability != null:
		ability.reset()


func has_shield(now: int) -> bool:
	return now < shield_until_tick


func is_stunned() -> bool:
	return stun_ticks > 0


func super_ready() -> bool:
	return super_charge >= SimConstants.SUPER_CHARGE_MAX


func add_super_charge(points: int) -> void:
	super_charge = mini(SimConstants.SUPER_CHARGE_MAX, super_charge + points)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"team": team,
		"brawler": data.id,
		"pos": pos,
		"facing": facing,
		"hp": hp,
		"alive": alive,
		"ammo": ammo,
		"reload": reload_progress,
		"super": super_charge,
		"stun": stun_ticks,
		"cooldown": cooldown_ticks,
		"shield": shield_until_tick,
		"knock": knock_ticks,
		"reveal": reveal_until_tick,
		"kills": kills,
		"deaths": deaths,
		"mode": mode_data,
	}
