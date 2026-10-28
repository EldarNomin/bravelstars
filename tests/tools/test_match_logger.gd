extends GutTest


func test_logger_drains_once_and_serializes_vectors_and_nested_values() -> void:
	var world := SimWorld.new(SimMap.from_lines(PackedStringArray(["..."])), 1)
	world.emit(SimEvents.HIT, {
		"target": 2, "source": 1, "pos": Vector2(1.25, 0.5),
		"extra": {"cell": Vector2i(1, 0), "kind": &"test"},
	})
	var logger := MatchLogger.new()
	logger.capture(world)
	assert_eq(logger.events.size(), 1)
	assert_eq(logger.events[0]["type"], "hit")
	assert_eq(logger.events[0]["tick"], 0)
	assert_eq(logger.events[0]["pos"], [1.25, 0.5])
	assert_eq(logger.events[0]["extra"], {"cell": [1, 0], "kind": "test"})
	assert_eq(world.drain_events().size(), 0, "logger consumes event queue once")
	logger.capture(world)
	assert_eq(logger.events.size(), 1)
