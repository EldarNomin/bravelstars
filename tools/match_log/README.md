# Журналы и статистика матчей ботов

Запускать из корня проекта после импорта Godot. Каталог журналов должен быть новым и пустым:

```sh
godot --headless --editor --import
mkdir -p /tmp/bravel-match-log
godot --headless -s tools/match_log/run_matches.gd -- \
  --output-dir=/tmp/bravel-match-log --revision="$(git rev-parse HEAD)"
python3 -m pip install 'Pillow>=10,<14'
python3 tools/match_log/summarize.py /tmp/bravel-match-log --output-dir /tmp/bravel-match-report
python3 tools/match_log/test_summarize.py
```

`MatchSetup` создаёт шесть персонажей, затем игрок добавляется в тот же `BotTeam` с обычной
сложностью. Используются все боевые карты обоих режимов и seed 1–20; если карт больше 20,
программа останавливается. Каждый тик `MatchLogger.capture()` единожды забирает очередь
`SimWorld.drain_events()`. События сериализуются целиком вместе с тиком; векторы представлены
парами чисел. Заголовок содержит seed, revision, режим, sha256 карты, состав, счёт и результат.

Определения TTK, HIT/атака, супер/мин и сдач указаны в отчёте. В частности, протокол не
связывает `HIT` с конкретным снарядом или выстрелом: HIT/атака может превышать 100% и не
является вероятностью успешного выстрела. В heatmap координата клетки равна `floor(pos)`;
фон показывает исходную карту, а не разрушения к моменту смерти.
