# Модели окружения и героев

Модели создаются локально скриптами Blender, сторонних ассетов и текстур нет. Для воспроизводимой сборки
используется **Blender 4.5.15 LTS**. Палитра `STYLE_HEX` в `common.py` соответствует `docs/STYLE.md`;
цвета переводятся из sRGB в линейное пространство Blender/glTF, оттенки выводятся из базовых цветов.

Из корня проекта:

```sh
blender -b --python-exit-code 1 -P tools/blender/build_all.py
blender -b --python-exit-code 1 -P tools/blender/verify_all.py
blender -b --python-exit-code 1 -P tools/blender/test_validation.py
blender -b --python-exit-code 1 -P tools/blender/render_preview.py
blender -b --python-exit-code 1 -P tools/blender/build_heroes.py
blender -b --python-exit-code 1 -P tools/blender/verify_heroes.py
blender -b --python-exit-code 1 -P tools/blender/render_heroes.py
godot --headless --editor --import
godot --headless -s tools/blender/check_heroes.gd
```

Первый набор команд пересобирает и проверяет десять GLB окружения и рисует `tools/blender/preview.png`.
Второй набор пересобирает и проверяет трёх героев, рисует два превью и проверяет импорт в Godot. Для
сборки во временную папку используйте `-- --output-dir /путь`, для проверки и рендера — `-- --input-dir /путь`.
Перед сравнением и коммитом файлов, отслеживаемых Git LFS, выполните `git lfs pull`.

Одна клетка — 1×1 м. Центр клетки расположен в начале координат, пол и объекты стоят на Z=0 в Blender;
вода находится ниже. Экспорт в glTF преобразует Z-up Blender в Y-up Godot. Пол — 1×1×0,055 м, ломаемая
стена — 1×1×1 м, непробиваемая — 1×1×1,2 м, кусты — до 1×1×0,7 м. Четыре отдельных обломка можно
использовать при разрушении. Фактическая геометрия каждой модели ограничена 300 треугольниками.
В A-02 окружение только перекрашено: его высоты пока отличаются от обновлённых значений в `STYLE.md`.

Герои используют одинаковые кости `root`, `spine`, `head_bone`, `arm.L`, `arm.R`, `leg.L`, `leg.R`.
Сокеты `head` и `muzzle` привязаны к костям. `idle` длится 1,5 с; настройки импорта `.glb.import`
задают его зацикливание в Godot. Остальные анимации относятся к A-03.

| Модель | Треугольники |
|---|---:|
| `floor` | 36 |
| `wall` | 180 |
| `hard_wall` | 84 |
| `bush_01`, `bush_02` | по 152 |
| `water` | 48 |
| `debris_01`…`debris_04` | по 16 |

Чтобы добавить модель, добавьте имя и ограничения в `ASSET_RULES` в `common.py`, процедурный генератор
в `build_all.py` и имя в `check_godot.gd`. Проверки считают треугольники и габариты до экспорта и после
повторного импорта, запрещают текстуры и проверяют загрузку всех GLB в Godot. CI пересобирает модели и
сверяет окружение побайтно, а героев — по импортированной геометрии, материалам, весам,
скелету, точкам привязки и позам анимации с допуском на различия вычислений между ОС.
