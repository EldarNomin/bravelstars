class_name MatchSetup
extends RefCounted
## Собирает готовый к игре матч по MatchConfig: мир, режим, игрок, союзники и противники — боты.
## Это единственное место, где «склеиваются» sim, modes и ai для запуска матча.

## Сложность ботов: множители skill и reaction_ticks, ошибка прицела (°), вероятность выстрела.
const DIFFICULTY_TUNING: Dictionary = {
	MatchConfig.Difficulty.EASY: {"skill": 0.5, "reaction": 1.8, "aim_error": 30.0, "trigger": 0.15},
	MatchConfig.Difficulty.NORMAL: {"skill": 1.0, "reaction": 1.0, "aim_error": 14.0, "trigger": 0.6},
	MatchConfig.Difficulty.HARD: {"skill": 1.3, "reaction": 0.6, "aim_error": 6.0, "trigger": 1.0},
}

var config: MatchConfig
var world: SimWorld
var player: SimBrawler
var bots: BotTeam


static func create(p_config: MatchConfig) -> MatchSetup:
	var s := MatchSetup.new()
	s.config = p_config
	var seed_value := p_config.seed_value
	if seed_value == 0:
		seed_value = randi()
	var map := SimMap.load_json(p_config.resolved_map_path())
	s.world = SimWorld.new(map, seed_value, load(MatchConfig.BALANCE_PATH))
	if p_config.mode == &"heist":
		var heist := Heist.new()
		s.world.mode = heist
		heist.setup(s.world)
	else:
		s.world.mode = TeamFight.new()
	s.bots = BotTeam.new(s.world)
	s.player = s.world.add_brawler(hero(p_config.hero_id), 0)
	for team in 2:
		for id in _roster(p_config, team):
			var b := s.world.add_brawler(hero(id), team)
			s.bots.add(b, tuned_profile(id, p_config.difficulty), seed_value)
	return s


static func hero(id: StringName) -> BrawlerData:
	return load("res://data/brawlers/%s.tres" % id) as BrawlerData


## Профиль роли героя с поправкой на сложность. Всегда копия — общий ресурс не меняется.
static func tuned_profile(id: StringName, difficulty: MatchConfig.Difficulty) -> BotProfile:
	var base := BotRoles.profile_for(id)
	var p: BotProfile = base.duplicate() if base != null else BotProfile.new()
	var k: Dictionary = DIFFICULTY_TUNING[difficulty]
	p.skill = clampf(p.skill * k["skill"], 0.05, 1.0)
	p.reaction_ticks = maxi(2, roundi(p.reaction_ticks * k["reaction"]))
	p.aim_error_deg = k["aim_error"]
	p.trigger_discipline = k["trigger"]
	return p


## Герои ботов: у своей команды — все, кроме героя игрока; у врагов — полный состав.
static func _roster(p_config: MatchConfig, team: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var i := 0
	while out.size() < p_config.team_size - (1 if team == 0 else 0):
		var id: StringName = MatchConfig.HEROES[i % MatchConfig.HEROES.size()]
		i += 1
		if team == 0 and id == p_config.hero_id and i <= MatchConfig.HEROES.size():
			continue
		out.append(id)
	return out


## Один тик: боты ставят команды, игрок — переданную, мир шагает.
func step(player_cmd: InputCommand) -> void:
	if player_cmd != null:
		world.set_input(player.id, player_cmd)
	bots.drive(world)
	world.step()
