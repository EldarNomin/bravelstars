class_name InputCommand
extends RefCounted
## Команда ввода на один тик. Её одинаково формируют игрок (UI), бот и сеть.
##
## Прицел — вектор в клетках карты относительно героя.
## Для прямых атак важно только направление, для навесных (LOB) — и длина (дальность броска).
## Нулевой прицел = автоприцел по ближайшему видимому врагу.

var move: Vector2 = Vector2.ZERO
var attack: bool = false
var attack_aim: Vector2 = Vector2.ZERO
var use_super: bool = false
var super_aim: Vector2 = Vector2.ZERO


static func create(
	p_move: Vector2 = Vector2.ZERO,
	p_attack: bool = false,
	p_attack_aim: Vector2 = Vector2.ZERO,
	p_use_super: bool = false,
	p_super_aim: Vector2 = Vector2.ZERO
) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.move = p_move
	cmd.attack = p_attack
	cmd.attack_aim = p_attack_aim
	cmd.use_super = p_use_super
	cmd.super_aim = p_super_aim
	return cmd


static func from_dict(d: Dictionary) -> InputCommand:
	return create(
		d.get("move", Vector2.ZERO),
		d.get("attack", false),
		d.get("attack_aim", Vector2.ZERO),
		d.get("use_super", false),
		d.get("super_aim", Vector2.ZERO)
	)


func to_dict() -> Dictionary:
	return {
		"move": move,
		"attack": attack,
		"attack_aim": attack_aim,
		"use_super": use_super,
		"super_aim": super_aim,
	}
