extends Node
## Глобальная шина сигналов для UI/мета-уровня.
## Симуляция (src/sim) сюда НЕ пишет: у неё свой список событий в SimWorld.events.

signal match_started
signal match_finished(result: Dictionary)
signal settings_changed
