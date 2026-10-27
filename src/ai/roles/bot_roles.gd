class_name BotRoles
extends RefCounted
## Характер ботов по героям: id -> BotProfile. Тюнинг значений — в src/ai/roles/*.tres.
## Неизвестный id -> null (BotBrain возьмёт BotProfile по умолчанию).

const PROFILES: Dictionary = {
	&"lynx": preload("res://src/ai/roles/lynx.tres"),
	&"anvil": preload("res://src/ai/roles/anvil.tres"),
	&"shishka": preload("res://src/ai/roles/shishka.tres"),
}


static func profile_for(id: StringName) -> BotProfile:
	return PROFILES.get(id) as BotProfile
