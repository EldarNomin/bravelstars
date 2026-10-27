extends SceneTree
# gdlint: disable=max-returns

const HEROES := ["lynx", "anvil", "shishka"]
const BONES := ["root", "spine", "head_bone", "arm.L", "arm.R", "leg.L", "leg.R"]
const CLIPS := {
	"idle": [1.2, 1.5, true, "spine"],
	"run": [0.6, 0.8, true, "leg.L"],
	"attack": [0.25, 0.35, false, "arm.R"],
	"super": [0.4, 0.6, false, "spine"],
	"death": [0.6, 0.8, false, "root"],
}


func _initialize() -> void:
	call_deferred("_check_heroes")


func _check_heroes() -> void:
	for hero_name in HEROES:
		var packed := load("res://assets/models/heroes/%s.glb" % hero_name) as PackedScene
		if packed == null:
			_fail(hero_name, "scene did not load")
			return
		var instance := packed.instantiate()
		root.add_child(instance)
		var skeletons := instance.find_children("*", "Skeleton3D", true, false)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		var heads := instance.find_children("head", "Node3D", true, false)
		var muzzles := instance.find_children("muzzle", "Node3D", true, false)
		if skeletons.size() != 1 or players.size() != 1 or heads.size() != 1 or muzzles.size() != 1:
			_fail(hero_name, "missing skeleton, animation player or sockets")
			return
		var skeleton := skeletons[0] as Skeleton3D
		var head := heads[0] as Node3D
		var muzzle := muzzles[0] as Node3D
		var player := players[0] as AnimationPlayer
		if skeleton.get_bone_count() != BONES.size():
			_fail(hero_name, "wrong bone count")
			return
		for bone in BONES:
			if skeleton.find_bone(bone) == -1:
				_fail(hero_name, "missing bone " + bone)
				return
		if not head.get_parent() is BoneAttachment3D or not muzzle.get_parent() is BoneAttachment3D:
			_fail(hero_name, "sockets are not attached to bones")
			return
		if head.position.length() == 0.0 or muzzle.global_position.y < 0.7:
			_fail(hero_name, "invalid socket position")
			return
		if muzzle.global_position.y > 0.9 or muzzle.global_position.z >= 0.0:
			_fail(hero_name, "muzzle must face forward at 0.7–0.9 m")
			return
		if not _check_clips(hero_name, player, skeleton):
			return
		instance.free()
		print("GODOT_HERO ", hero_name, " skeleton, sockets and five clips OK")
	quit(0)


func _check_clips(hero_name: String, player: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	for clip in CLIPS:
		if not player.has_animation(clip):
			_fail(hero_name, "missing animation " + clip)
			return false
		var animation := player.get_animation(clip)
		var rule: Array = CLIPS[clip]
		if animation.length < rule[0] - 0.001 or animation.length > rule[1] + 0.001:
			_fail(hero_name, "wrong duration for " + clip)
			return false
		var loop_mode := Animation.LOOP_LINEAR if rule[2] else Animation.LOOP_NONE
		if animation.loop_mode != loop_mode:
			_fail(hero_name, "wrong loop mode for " + clip)
			return false
		player.play(clip)
		player.advance(0.0)
		var bone := skeleton.find_bone(rule[3])
		var initial := skeleton.get_bone_pose_rotation(bone)
		player.advance(animation.length * 0.5)
		if initial.is_equal_approx(skeleton.get_bone_pose_rotation(bone)):
			_fail(hero_name, clip + " does not animate " + rule[3])
			return false
	return true


func _fail(hero_name: String, reason: String) -> void:
	push_error("GODOT_HERO %s: %s" % [hero_name, reason])
	quit(1)
