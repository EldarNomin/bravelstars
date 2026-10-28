"""Metric semantics: multiple hits, super exclusion, respawns and deposits."""

import unittest

from summarize import summarize


class SummaryTest(unittest.TestCase):
    def test_events_and_lives(self):
        players = [{"id": i, "hero": "lynx" if i % 2 else "anvil", "team": i % 2}
                   for i in range(1, 7)]
        events = [
            {"tick": 0, "type": "match_start"},
            {"tick": 3, "type": "attack", "brawler": 1, "super": False},
            {"tick": 6, "type": "hit", "source": 1, "target": 2, "super": False},
            {"tick": 9, "type": "hit", "source": 1, "target": 2, "super": False},
            {"tick": 12, "type": "super", "brawler": 1},
            {"tick": 15, "type": "attack", "brawler": 1, "super": True},
            {"tick": 18, "type": "hit", "source": 1, "target": 2, "super": True},
            {"tick": 18, "type": "death", "target": 2, "pos": [1.2, 2.7]},
            {"tick": 20, "type": "respawn", "brawler": 2},
            {"tick": 21, "type": "hit", "source": 1, "target": 2, "super": False},
            {"tick": 24, "type": "death", "target": 2, "pos": [1.9, 2.1]},
            {"tick": 25, "type": "deposit", "brawler": 1, "amount": 3},
            {"tick": 29, "type": "match_end"},
        ]
        record = {"schema_version": 1, "seed": 1, "players": players, "events": events,
                  "map": "res://test.json", "tick_rate": 30, "winner": 0}
        heroes, maps = summarize([record])
        self.assertEqual((heroes["lynx"]["shots"], heroes["lynx"]["hits"]), (1, 3))
        self.assertEqual(heroes["lynx"]["supers"], 1)
        self.assertEqual((heroes["lynx"]["deposits"], heroes["lynx"]["shards"]), (1, 3))
        self.assertEqual(heroes["anvil"]["ttk"], [0.4, 0.1])
        self.assertEqual(maps[record["map"]]["deaths"][(1, 2)], 2)
        self.assertEqual(heroes["lynx"]["seconds"], 3.0)

    def test_missing_end_is_rejected(self):
        record = {"schema_version": 1, "seed": 1, "players": [
            {"id": i, "hero": "lynx", "team": 0} for i in range(6)
        ], "events": [{"tick": 0, "type": "match_start"}], "map": "m", "tick_rate": 30}
        with self.assertRaises(ValueError):
            summarize([record])


if __name__ == "__main__":
    unittest.main()
