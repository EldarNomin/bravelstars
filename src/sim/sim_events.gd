class_name SimEvents
extends RefCounted
## Типы событий SimWorld.events. У каждого события есть поля "type" и "tick", остальные — ниже.

## brawler, super: bool, dir: Vector2, pos: Vector2
const ATTACK: StringName = &"attack"
## brawler, aim: Vector2 (сырой прицел игрока)
const SUPER: StringName = &"super"
## target, source (0 — нет), amount, super: bool, pos
const HIT: StringName = &"hit"
## target, amount
const HEAL: StringName = &"heal"
## target, killer (0 — нет), pos
const DEATH: StringName = &"death"
## brawler, pos
const RESPAWN: StringName = &"respawn"
## pos, radius, super: bool
const EXPLOSION: StringName = &"explosion"
## cell: Vector2i, tile: SimMap.Tile (что было)
const TILE_DESTROYED: StringName = &"tile_destroyed"
## cell: Vector2i, tile: SimMap.Tile (что появилось)
const TILE_RESTORED: StringName = &"tile_restored"
## projectile, pos
const PROJECTILE_END: StringName = &"projectile_end"
## (без полей) — отсчёт закончился, бой начался
const MATCH_START: StringName = &"match_start"
## scores: Dictionary команда -> очки
const SCORE: StringName = &"score"
## winner: команда (-1 — ничья), scores, reason: "score" | "time"
const MATCH_END: StringName = &"match_end"
## pos, kind — на карте появился предмет (осколок и т.п.)
const PICKUP_SPAWNED: StringName = &"pickup_spawned"
## brawler, pos, kind — предмет подобран
const PICKUP_TAKEN: StringName = &"pickup_taken"
## brawler, team, amount — добыча сдана в сейф
const DEPOSIT: StringName = &"deposit"
## brawler, dir
const DASH_START: StringName = &"dash_start"
