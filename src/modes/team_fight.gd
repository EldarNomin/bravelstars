class_name TeamFight
extends GameMode
## Бой команд: побеждает команда, первой набравшая kills_to_win убийств, или лидер по истечении времени.

var kills_to_win: int = 10


func _init(p_kills_to_win: int = 10, duration_sec: float = 120.0, countdown_sec: float = 3.0) -> void:
	kills_to_win = p_kills_to_win
	duration_ticks = SimConstants.ticks(duration_sec)
	countdown_ticks = SimConstants.ticks(countdown_sec)
	scores = {0: 0, 1: 0}


func on_kill(world: SimWorld, victim: SimBrawler, killer: SimBrawler) -> void:
	if phase != Phase.PLAYING or killer == null or killer.team == victim.team:
		return
	add_score(world, killer.team, 1)
	if scores[killer.team] >= kills_to_win:
		finish(world, killer.team, "score")
