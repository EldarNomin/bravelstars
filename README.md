# Bravel Stars (рабочее название)

Мобильный арена-шутер 3v3 на Godot 4, сначала Android.

- План: [docs/PLAN.md](docs/PLAN.md)
- Задачи и кто их делает: [docs/TASKS.md](docs/TASKS.md)
- Правила для агентов: [AGENTS.md](AGENTS.md)

## Как скачать APK

1. Откройте [Actions → Godot CI](https://github.com/EldarNomin/bravelstars/actions/workflows/ci.yml) и выберите успешный запуск нужной ветки.
2. Внизу, в **Artifacts**, скачайте `bravelstars-debug-apk` (нужен вход в GitHub) и распакуйте ZIP.
3. Откройте `bravelstars-debug.apk` на Android с arm64 и разрешите установку из выбранного источника.

## Тесты локально

Нужен Godot из `.godot-version` и Bash (в Windows — Git Bash).
Запуск: `bash tools/run_tests.sh`; если Godot не в PATH, задайте `GODOT_BIN=/путь/к/godot`.
Линтер: `python -m pip install 'gdtoolkit==4.*'`, затем `gdlint src tests tools`.
