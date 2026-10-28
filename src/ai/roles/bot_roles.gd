class_name BotRoles
extends RefCounted
## Характер ботов по героям: id -> BotProfile. Тюнинг значений — в src/ai/roles/*.tres.
## Неизвестный id -> null (BotBrain возьмёт BotProfile по умолчанию).

const PROFILES: Dictionary = {
	&"lynx": preload("res://src/ai/roles/lynx.tres"),
	&"anvil": preload("res://src/ai/roles/anvil.tres"),
	&"shishka": preload("res://src/ai/roles/shishka.tres"),
}


## Копия ресурса: настройка профиля одного бота не должна менять других.
static func profile_for(id: StringName) -> BotProfile:
	var p := PROFILES.get(id) as BotProfile
	return p.duplicate() if p != null else null
