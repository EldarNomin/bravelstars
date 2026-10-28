class_name MatchLogger
extends RefCounted
## Sole consumer of SimWorld's event queue for a headless match.

var events: Array[Dictionary] = []


func capture(world: SimWorld) -> void:
	for event in world.drain_events():
		events.append(_json_value(event))


func _json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var out: Array = []
			for item in value:
				out.append(_json_value(item))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in value:
				out[str(key)] = _json_value(value[key])
			return out
	return value
