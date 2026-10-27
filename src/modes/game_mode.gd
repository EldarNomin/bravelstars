class_name GameMode
extends RefCounted
## Базовый режим матча: отсчёт → бой → результат. Живёт внутри SimWorld (world.mode),
## поэтому подчиняется правилам src/sim: только тики, без Input/Time/узлов.

enum Phase { COUNTDOWN, PLAYING, FINISHED }

var phase: Phase = Phase.COUNTDOWN
var countdown_ticks: int = SimConstants.ticks(3.0)
var duration_ticks: int = SimConstants.ticks(120.0)
## Сколько тиков боя осталось (для таймера в UI).
var ticks_left: int = 0
## Команда -> очки.
var scores: Dictionary = {}
## -1 — ничья или матч не закончен.
var winner: int = -1
var end_reason: String = ""

var _started_at: int = -1


func accepts_input() -> bool:
	return phase == Phase.PLAYING


func is_finished() -> bool:
	return phase == Phase.FINISHED


## Секунд до начала боя (для отсчёта 3-2-1 в UI).
func countdown_left(world: SimWorld) -> float:
	return maxf(0.0, float(countdown_ticks - world.tick) / SimConstants.TICK_RATE)


func tick(world: SimWorld) -> void:
	match phase:
		Phase.COUNTDOWN:
			if world.tick + 1 >= countdown_ticks:
				phase = Phase.PLAYING
				_started_at = world.tick + 1
				ticks_left = duration_ticks
				world.emit(SimEvents.MATCH_START, {})
		Phase.PLAYING:
			ticks_left -= 1
			on_playing_tick(world)
			if phase == Phase.PLAYING and ticks_left <= 0:
				finish(world, _leader(), "time")


## Переопределяется режимами (шахта, зона захвата...).
func on_playing_tick(_world: SimWorld) -> void:
	pass


## Вызывается SimWorld при каждом убийстве.
func on_kill(_world: SimWorld, _victim: SimBrawler, _killer: SimBrawler) -> void:
	pass


func add_score(world: SimWorld, team: int, points: int) -> void:
	scores[team] = scores.get(team, 0) + points
	world.emit(SimEvents.SCORE, {"scores": scores.duplicate()})


func finish(world: SimWorld, p_winner: int, reason: String) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	winner = p_winner
	end_reason = reason
	world.emit(SimEvents.MATCH_END, {"winner": winner, "scores": scores.duplicate(), "reason": reason})


## Команда с наибольшим счётом или -1 при равенстве.
func _leader() -> int:
	var best := -1
	var best_score := -1
	var tie := false
	for team: int in scores.keys():
		if scores[team] > best_score:
			best_score = scores[team]
			best = team
			tie = false
		elif scores[team] == best_score:
			tie = true
	return -1 if tie else best
