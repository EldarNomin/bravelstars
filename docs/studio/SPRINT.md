# Спринт 1 (2 недели) → VS0

**Цель спринта:** на телефоне владельца — APK из CI, джойстики, отладочная арена с ботами.

**Владелец:** день 1 — смержить #1, затем #2 (потом #3), ~~утвердить `docs/DESIGN.md` (D-01)~~ — сделано. Суббота 1-й недели — первый APK на телефон. Суббота 2-й недели — первый плейтест по `docs/playtest/TEMPLATE.md`.

Порядок: сначала Codex (CI — критический путь), параллельно Antigravity; GLM — после D-01. Claude параллельно: C-10, G-01, C-17.

---

## Codex — F-03

```
Задача: F-03 GUT + CI + APK. Репозиторий: github.com/EldarNomin/bravelstars.
Ветка: codex/F-03-ci от свежего main.

Прочитай: AGENTS.md, docs/TASKS.md (строка F-03), .godot-version, gdlintrc, tests/sim/*.

Можно менять: addons/gut/, .github/, tools/, export_presets.cfg. Нельзя: src/, data/, project.godot, docs/TASKS.md.

Что сделать:
1. Добавить GUT 9.7.1 (github.com/bitwes/Gut, тег v9.7.1) в addons/gut. Плагин в project.godot не включать.
2. tools/run_tests.sh: импорт проекта headless, затем
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit; код выхода ≠ 0 при падении.
3. GitHub Actions на push и PR: Godot 4.7.2 (версию брать из .godot-version), gdlint src tests tools (pip gdtoolkit 4.*), tools/run_tests.sh.
4. Отдельная задача в том же workflow: экспорт debug APK (шаблоны экспорта 4.7.2, Android SDK, debug keystore генерируется в CI), APK — артефакт сборки.
5. export_presets.cfg с пресетом "Android" (arm64-v8a, ландшафт, ETC2/ASTC).
6. В README: раздел «Как скачать APK» (3 строки).

Готово, когда:
- все 42 теста tests/sim зелёные в CI, gdlint чистый;
- APK скачивается из артефактов и ставится на Android-телефон.

Проверка перед PR: tools/run_tests.sh зелёный локально. Непонятно — вопрос в PR.
PR: "F-03: GUT + CI + APK".
```

## Antigravity — F-05, затем C-05

```
Задача: F-05 стиль и заглушки. Репозиторий: github.com/EldarNomin/bravelstars.
Ветка: antigravity/F-05-style от свежего main.

Прочитай: AGENTS.md, docs/DESIGN.md (столпы, §4), docs/map_format.md, src/view/debug/debug_match.gd.
Можно менять: assets/, docs/STYLE.md. Нельзя: src/sim, data/, project.godot, docs/TASKS.md.

Что сделать:
1. docs/STYLE.md: стиль low-poly, палитра (пол, стена, непробиваемая стена, куст, вода, 2 цвета команд),
   команда различается цветом И формой (кольцо/треугольник под героем), пропорции героя к клетке 1×1, высоты объектов.
2. Заглушки в assets/placeholder/ (.glb или .tres-меши): герой, стена, непробиваемая стена, куст (полупрозрачный), вода.
3. Ничего из Brawl Stars: ни форм, ни цветов-логотипов.

Готово, когда: STYLE.md и 5 заглушек в репо; скриншот сцены с ними в PR.
PR: "F-05: стиль и заглушки".
```

```
Задача: C-05 сенсорные джойстики. Репозиторий: github.com/EldarNomin/bravelstars.
Ветка: antigravity/C-05-joysticks от свежего main (после F-05).

Прочитай: AGENTS.md, src/sim/input_command.gd (смысл прицела!), src/view/debug/debug_match.gd (как сейчас собирается InputCommand).
Можно менять: src/ui/, scenes/ui/. Нельзя: src/sim, project.godot, docs/TASKS.md.

Что сделать:
1. Левый джойстик — движение (Vector2 длиной ≤ 1). Появляется там, где палец коснулся левой половины экрана.
2. Правый джойстик атаки: тянуть — показывать прицел, отпустить — выстрел с attack_aim = направление × дальность атаки;
   короткий тап без оттягивания — выстрел с attack_aim = Vector2.ZERO (автоприцел).
3. Кнопка супера (такая же механика, активна только при brawler.super_ready()).
4. Мультитач: бег и прицел одновременно. Мёртвая зона ~10%.
5. Узел отдаёт готовый InputCommand на каждый тик (метод build_command()), сам в симуляцию не пишет.
6. Подключить к отладочной сцене вместо мыши (минимальная правка debug_match.gd допустима).

Готово, когда: видео с Android-телефона — бег + прицел одновременно, тап = автоприцел, супер.
PR: "C-05: джойстики".
```

## GLM — C-09 (DESIGN.md утверждён, можно начинать после мержа #2)

```
Задача: C-09 три стартовых героя. Репозиторий: github.com/EldarNomin/bravelstars.
Ветка: glm/C-09-brawlers от свежего main.

Прочитай: AGENTS.md, docs/templates/brawler.md (полностью!), docs/DESIGN.md §5–6,
data/brawlers/_prototype.tres, src/sim/data/*.gd, src/sim/supers/dash_super.gd, tests/sim/test_sim_combat.gd.
Можно менять: data/brawlers/, src/sim/supers/, tests/sim/brawlers/. Нельзя: остальной src/sim, project.godot, docs/TASKS.md.

Что сделать:
1. data/brawlers/lynx.tres, anvil.tres, shishka.tres — числа из DESIGN.md §6, недостающие — из таблицы шаблона.
2. Суперы: lynx — обычный super_attack (pierce); anvil — src/sim/supers/ram_super.gd на основе DashSuper
   (ломает стены по пути, отбрасывает), с reset(); shishka — LOB super_attack с breaks_walls.
3. super_charge_per_hit — целые из 1000.
4. Тесты tests/sim/brawlers/test_<id>.gd: урон попадания, заряд супера за заявленное число попаданий, супер срабатывает;
   для anvil — таран ломает стену и не продолжается после смерти.
5. В описании PR — карточка каждого героя по шаблону §1.

Готово, когда: 3 .tres + 1 скрипт + тесты, tools/run_tests.sh зелёный.
PR: "C-09: Рысь, Наковальня, Шишка".
```
