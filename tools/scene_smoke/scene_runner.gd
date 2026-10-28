extends SceneTree
## Runs the actual scene and gives its local player to the scene's existing BotTeam.

const TARGET_TICKS: int = 60 * SimConstants.TICK_RATE
var scene: Node
var world: SimWorld
var start_pos: Vector2
var saw_player_action: bool = false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	var path := ""
	for arg in args:
		if arg.begins_with("--smoke-scene="):
			path = arg.trim_prefix("--smoke-scene=")
	if path.is_empty():
		_fail("missing --smoke-scene")
		return
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("scene did not load: " + path)
		return
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	world = scene.get("world") as SimWorld
	var player := scene.get("player") as SimBrawler
	var bots: BotTeam
	if scene is MatchView:
		bots = scene.get("bot_team") as BotTeam
	else:
		bots = scene.get("_bots") as BotTeam
	if world == null or player == null or bots == null or bots.brains.size() != 5:
		_fail("scene did not initialize its 3v3 match and five bots")
		return
	bots.add(player, MatchSetup.tuned_profile(player.data.id, MatchConfig.Difficulty.NORMAL), 42)
	start_pos = player.pos
	if args.has("--smoke-no-hud"):
		var hud_layer := scene.get_node_or_null("UICanvas")
		if hud_layer == null:
			_fail("no HUD canvas to hide for the comparison frame")
			return
		(hud_layer as CanvasLayer).visible = false
	print("SMOKE_START ", path, " brawlers=", world.brawlers.size(), " bots=", bots.brains.size())


func _process(_delta: float) -> bool:
	if world == null:
		return false
	var player := scene.get("player") as SimBrawler
	if player.pos.distance_to(start_pos) > 0.05 or player.last_attack_tick >= 0:
		saw_player_action = true
	if world.tick >= TARGET_TICKS:
		if not saw_player_action:
			_fail("player bot never moved or attacked")
			return false
		print("SMOKE_OK ticks=", world.tick, " bot_acted=", saw_player_action)
		quit(0)
	return false


func _fail(message: String) -> void:
	push_error("SCENE_SMOKE: " + message)
	quit(1)
