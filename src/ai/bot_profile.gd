class_name BotProfile
extends Resource
## Характер бота. Тюнинг по ролям — в src/ai/roles/*.tres (задача C-10b).

## 0..1: точность прицела, упреждение, скорость реакции.
@export_range(0.0, 1.0) var skill: float = 0.5
## Желаемая дистанция боя как доля дальности атаки.
@export var preferred_range: float = 0.75
## Ниже этой доли HP — отступать.
@export var retreat_hp: float = 0.35
## Сколько тиков думать между сменами решения (меньше — резче).
@export var reaction_ticks: int = 6
## Склонность прятаться в кустах при отступлении и ожидании.
@export var bush_preference: float = 0.6
## Сколько секунд помнит, где последний раз видел врага.
@export var memory_time: float = 2.5
## Максимальная ошибка прицела в градусах при skill = 0 (масштабируется на 1 - skill).
@export var aim_error_deg: float = 14.0
## Вероятность выстрелить, когда выстрел возможен (0..1). Ниже — бот «зевает».
@export_range(0.0, 1.0) var trigger_discipline: float = 1.0
