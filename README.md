# Bravel Stars (рабочее название)

Мобильный арена-шутер 3v3 на Godot 4, сначала Android.

- План: [docs/PLAN.md](docs/PLAN.md)
- Задачи и кто их делает: [docs/TASKS.md](docs/TASKS.md)
- Правила для агентов: [AGENTS.md](AGENTS.md)

## Как скачать APK

1. GitHub → вкладка **Actions** → последний зелёный запуск **CI** нужной ветки.
2. Внизу страницы, в **Artifacts**, скачать `bravelstars-debug-apk` (zip с APK внутри).
3. Перекинуть APK на Android-телефон и установить (разрешить установку из неизвестных источников).

## Тесты

`tools/run_tests.sh путь/к/godot` — все GUT-тесты headless.
