extends SceneTree

const MODELS := [
	"lynx_bullet", "anvil_pellet", "pinecone", "pinecone_super",
	"loot_shard", "safe_blue", "safe_red", "mine",
]


func _initialize() -> void:
	call_deferred("_check_models")


func _check_models() -> void:
	for model in MODELS:
		var packed := load("res://assets/models/fx/%s.glb" % model) as PackedScene
		if packed == null:
			push_error("Cannot load FX " + model)
			quit(1)
			return
		var instance := packed.instantiate()
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		if instance is MeshInstance3D:
			meshes.append(instance)
		if meshes.size() == 0:
			instance.free()
			push_error("No mesh in FX " + model)
			quit(1)
			return
		if model == "lynx_bullet" and not _has_emission(meshes):
			instance.free()
			push_error("Bullet trail lost its emissive material")
			quit(1)
			return
		instance.free()
		print("GODOT_FX ", model, " OK")
	quit(0)


func _has_emission(meshes: Array[Node]) -> bool:
	for node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.emission_enabled:
				return true
	return false
