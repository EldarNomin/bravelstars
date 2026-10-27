class_name BotTeam
extends RefCounted
## Управляет всеми ботами мира: один вызов на тик ставит команды всем ботам.

var nav: BotNav
var brains: Array[BotBrain] = []


func _init(world: SimWorld) -> void:
	nav = BotNav.new(world.map)


func add(brawler: SimBrawler, profile: BotProfile = null, seed_value: int = 0) -> BotBrain:
	var prof := profile if profile != null else BotRoles.profile_for(brawler.data.id)
	var brain := BotBrain.new(brawler.id, nav, prof, seed_value)
	brains.append(brain)
	return brain


func drive(world: SimWorld) -> void:
	for brain in brains:
		world.set_input(brain.brawler_id, brain.think(world))
