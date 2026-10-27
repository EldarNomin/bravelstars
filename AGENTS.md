# Правила для агентов (Claude, Codex, Antigravity, GLM)

Читать перед любой задачей: `docs/PLAN.md` (что и зачем), `docs/DESIGN.md` (какую игру делаем), `docs/TASKS.md` (кто что делает), `docs/studio/PROCESS.md` (как работает студия).

## Как брать задачу

1. Берёшь только задачу, где в колонке «Агент» указан ты, и все задачи из «После» готовы.
2. Ветка: `<агент>/<ID>-кратко` **от свежего `dev`**, например `codex/C-12-bench`, `glm/C-11-maps`. PR — **в `dev`** (интеграционная ветка). `main` — стабильная, в неё попадает только проверенный `dev`.
3. Одна задача = один PR в `dev`, до ~400 строк кода. В заголовке PR — ID задачи. Перед PR — ребейз на свежий `main`.
   `docs/TASKS.md` и `project.godot` в PR **не трогать** — статусы и настройки проекта ведёт Claude.
4. Ревью всех PR делает Claude. Сам в `main` не мержишь.
5. Не понятно или задача требует выйти за свои папки — пиши вопрос в PR, а не угадывай.

## Рабочие копии на ПК

Агенты работают на одном компьютере в `mobilegames/`. **Каждый — в своём `git worktree`**, чужие не переключать:

| Агент | Папка |
|---|---|
| Antigravity | `mobilegames/bravelstars` (основной клон) |
| Codex | `mobilegames/bravelstars-codex` |
| GLM | `mobilegames/bravelstars-glm` |

Создать: `git -C mobilegames/bravelstars worktree add ../bravelstars-<агент> origin/dev`.

## Владение папками

Править чужие папки можно только минимально и с пояснением в PR.

| Папка | Владелец |
|---|---|
| `src/core/`, `src/sim/`, `src/net/`, `src/modes/` (каркас), `src/ai/` (каркас), `project.godot` | Claude |
| `src/view/`, `src/ui/`, `scenes/ui/`, `assets/ui/`, `assets/vfx/`, `assets/textures/` | Antigravity |
| `assets/models/` (3D-модели, анимации), `tools/blender/` (скрипты генерации и экспорта моделей) | Codex |
| `data/` (герои, карты, баланс), `src/sim/supers/`, `tests/sim/brawlers/`, `src/ai/roles/` (тюнинг), `locale/` | GLM |
| `.github/`, `tests/`, `tools/`, `server/`, `export_presets.cfg`, `src/meta/backend/` | Codex |
| `docs/` | все, но `PLAN.md` меняет только Claude |

## Структура проекта

```
src/
  core/      автозагрузки: Events (сигнальная шина), Config
  sim/       ЛОГИКА игры: тики 30 Гц, сущности, бой. Без Node3D-визуала, без Input.
  view/      отображение состояния sim: модели, анимации, VFX, камера
  ui/        HUD, джойстики, меню
  ai/        боты (выдают те же InputCommand, что и игрок)
  modes/     режимы матча
  net/       сетевой код
  meta/      профиль, прогресс, бэкенд
data/        .tres/.json: герои, карты, баланс
assets/      модели, текстуры, звук, шрифты
scenes/      .tscn
tests/       GUT-тесты (зеркалят src/)
tools/       скрипты
server/      Dockerfile, конфиги сервера
docs/
```

## Главное архитектурное правило

**`src/sim` ничего не знает про отображение, ввод и сеть.** Он получает `InputCommand` от игрока/бота/сети и меняет состояние мира. `src/view` только читает состояние. Нарушение этого правила сломает мультиплеер в фазе 3 — такие PR не принимаются.

- В `src/sim` никаких `Input.*`, `randf()` без общего seed, `Time.get_ticks_*`, `_process`. Только шаг тика.
- Случайность — через общий RNG симуляции с seed.
- Ресурсы `BrawlerData`/`AttackData` в симуляции только читаются — они общие для всех копий героя.
- События — только `world.emit(SimEvents.<ТИП>, {...})`; отображение забирает их через `world.drain_events()`.
- Состояние суперов сбрасывается в `SuperAbility.reset()`.

## Стиль кода

- GDScript со статической типизацией везде: `var hp: int = 100`, `func take_damage(amount: int) -> void:`.
- `snake_case` для файлов, функций, переменных; `PascalCase` для `class_name`; константы `UPPER_CASE`.
- Числа баланса — в `data/`, не в коде.
- Перед PR: `gdlint` без ошибок, `tools/run_tests.sh` зелёный (после F-04).
- Новый код в `src/sim`, `src/ai`, `src/modes` — с тестами GUT.

## Определение «готово»

- Выполнен пункт «Готово, когда» из `docs/TASKS.md`.
- CI зелёный, есть тесты на логику.
- Для визуала/управления — в PR скриншот или видео (с телефона, если задача про ввод).

## IP

Никаких имён, персонажей, арта, звуков и названий режимов из Brawl Stars. Всё своё.
