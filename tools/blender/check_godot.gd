extends SceneTree

const MODELS: Array[String] = [
	"floor", "wall", "hard_wall", "bush_01", "bush_02", "water",
	"debris_01", "debris_02", "debris_03", "debris_04",
]


func _initialize() -> void:
	call_deferred("_check_models")


func _check_models() -> void:
	for model_name in MODELS:
		var path := "res://assets/models/env/%s.glb" % model_name
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Cannot load " + path)
			quit(1)
			return
		var instance := packed.instantiate()
		var count := instance.find_children("*", "MeshInstance3D", true, false).size()
		if instance is MeshInstance3D:
			count += 1
		instance.free()
		if count == 0:
			push_error("No mesh instances in " + path)
			quit(1)
			return
		print("GODOT_MODEL ", model_name, " mesh instances: ", count)
	print("GODOT_MODEL all 10 GLBs loaded")
	quit()
