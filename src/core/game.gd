extends Node
## Состояние приложения между сценами: какой матч запустить следующим и результат последнего.

var next_match: MatchConfig = MatchConfig.make(&"teamfight")
var last_result: Dictionary = {}
