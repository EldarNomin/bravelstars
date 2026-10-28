"""Summarize event journals and render per-map death heatmaps."""

import argparse
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def summarize(records):
    heroes = defaultdict(lambda: {"shots": 0, "hits": 0, "supers": 0, "seconds": 0.0,
                                  "ttk": [], "deaths": 0, "deposits": 0, "shards": 0})
    maps = defaultdict(lambda: {"matches": 0, "deaths": Counter(), "deposits": 0,
                                "shards": 0, "durations": [], "winners": Counter()})
    seeds = set()
    for record in records:
        if record["schema_version"] != 1 or record["seed"] in seeds:
            raise ValueError("Unsupported schema or duplicate seed")
        seeds.add(record["seed"])
        by_id = {p["id"]: p["hero"] for p in record["players"]}
        if len(by_id) != 6:
            raise ValueError("Expected six distinct participants")
        events = record["events"]
        if any(a["tick"] > b["tick"] for a, b in zip(events, events[1:])):
            raise ValueError("Events are out of order")
        starts = [e["tick"] for e in events if e["type"] == "match_start"]
        ends = [e["tick"] for e in events if e["type"] == "match_end"]
        if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
            raise ValueError("Match has no valid start and end")
        seconds = (ends[0] - starts[0] + 1) / record["tick_rate"]
        game = maps[record["map"]]
        game["matches"] += 1
        game["durations"].append(seconds)
        game["winners"][record["winner"]] += 1
        for player in record["players"]:
            heroes[player["hero"]]["seconds"] += seconds
        first_hit = {}
        for event in events:
            kind = event["type"]
            if kind == "attack" and not event.get("super", False):
                heroes[by_id[event["brawler"]]]["shots"] += 1
            elif kind == "hit":
                target = event["target"]
                first_hit.setdefault(target, event["tick"])
                source = event.get("source", 0)
                if source in by_id and not event.get("super", False):
                    heroes[by_id[source]]["hits"] += 1
            elif kind == "super":
                heroes[by_id[event["brawler"]]]["supers"] += 1
            elif kind == "death":
                target = event["target"]
                hero = heroes[by_id[target]]
                hero["deaths"] += 1
                if target in first_hit:
                    hero["ttk"].append((event["tick"] - first_hit[target]) / record["tick_rate"])
                first_hit.pop(target, None)
                x, y = event["pos"]
                game["deaths"][(math.floor(x), math.floor(y))] += 1
            elif kind == "respawn":
                first_hit.pop(event["brawler"], None)
            elif kind == "deposit":
                hero = heroes[by_id[event["brawler"]]]
                hero["deposits"] += 1
                hero["shards"] += event["amount"]
                game["deposits"] += 1
                game["shards"] += event["amount"]
    return heroes, maps


def heatmap(map_path, stats, max_deaths, output):
    source = ROOT / map_path.removeprefix("res://")
    data = json.loads(source.read_text(encoding="utf-8"))
    grid = data["grid"]
    size, top, bottom = 20, 40, 55
    image = Image.new("RGB", (len(grid[0]) * size, len(grid) * size + top + bottom), "#20252a")
    draw = ImageDraw.Draw(image)
    colors = {"X": "#3e444c", "#": "#965a38", "*": "#2d6a4f", "~": "#2a8794"}
    for y, row in enumerate(grid):
        for x, tile in enumerate(row):
            box = (x * size, top + y * size, (x + 1) * size - 1, top + (y + 1) * size - 1)
            draw.rectangle(box, fill=colors.get(tile, "#7d6b58"))
            value = stats["deaths"].get((x, y), 0)
            if value:
                ratio = value / max_deaths
                draw.rectangle(box, fill=(int(135 + 120 * ratio), int(48 * (1 - ratio)), 25))
                draw.text((x * size + 5, top + y * size + 3), str(value), fill="white")
    draw.text((10, 12), f"{source.stem} - deaths per cell - {stats['matches']} matches", fill="white")
    draw.text((10, image.height - 37), f"Red = deaths; numbers = count; common maximum = {max_deaths}", fill="white")
    draw.text((10, image.height - 20), "Walls: brown/grey; bushes: green; water: blue", fill="white")
    image.save(output)


def write_report(records, output):
    if len(records) != 20:
        raise ValueError("Expected exactly 20 match journals")
    heroes, maps = summarize(records)
    revisions = {record["revision"] for record in records}
    if len(revisions) != 1:
        raise ValueError("Different simulation revisions")
    for record in records:
        path = ROOT / record["map"].removeprefix("res://")
        if hashlib.sha256(path.read_bytes()).hexdigest() != record["map_sha256"]:
            raise ValueError(f"Map differs from journal: {path}")
    output.mkdir(parents=True, exist_ok=True)
    maximum = max((max(s["deaths"].values(), default=0) for s in maps.values()), default=0) or 1
    lines = [
        "# C-16: статистика 20 матчей ботов", "",
        f"Симуляция: `{next(iter(revisions))}`; 20 уникальных seed 1–20, NORMAL, 3v3. "
        "Игрок также управляется ботом; `MatchSetup` создаёт матч. Карты и режимы чередуются. "
        "Это небольшая диагностическая выборка, не оценка баланса B-01.", "",
        "Время до смерти (TTK) — от первого HIT за текущую жизнь до DEATH цели, включая помощь "
        "союзников и возможную регенерацию; среднее по погибшим. Не означает время дуэли 1v1.", "",
        "Попадания/выстрелы — число событий HIT обычной атаки / число событий ATTACK обычной атаки. "
        "У дробовика и взрыва один выстрел может вызвать несколько HIT, поэтому значение может "
        "превышать 100%; это не вероятность попадания и не точность отдельных снарядов. "
        "Суперы исключены из обоих чисел. SUPER/мин — на одну минуту участия героя в боевой фазе. "
        "Сдачи: число DEPOSIT и число сданных осколков.", "",
        "| Герой | Выстрелы | HIT | HIT/выстрел | TTK до смерти, с (n) | Смерти | Суперы/мин | Сдачи / осколки |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for name, value in sorted(heroes.items()):
        accuracy = f"{100 * value['hits'] / value['shots']:.1f}%" if value["shots"] else "—"
        ttk = f"{sum(value['ttk']) / len(value['ttk']):.2f} ({len(value['ttk'])})" if value["ttk"] else "—"
        super_rate = 60 * value["supers"] / value["seconds"] if value["seconds"] else 0
        lines.append(f"| {name} | {value['shots']} | {value['hits']} | {accuracy} | {ttk} | "
                     f"{value['deaths']} | {super_rate:.2f} | {value['deposits']} / {value['shards']} |")
    lines += ["", "| Карта | Режим | Матчи | Среднее время боя, с | Смерти | Сдачи / осколки | Теплокарта |",
              "|---|---|---:|---:|---:|---:|---|"]
    for path, value in sorted(maps.items()):
        source = ROOT / path.removeprefix("res://")
        map_data = json.loads(source.read_text(encoding="utf-8"))
        filename = f"heatmap_{source.stem}.png"
        heatmap(path, value, maximum, output / filename)
        lines.append(f"| {map_data['name']} | {map_data['mode']} | {value['matches']} | "
                     f"{sum(value['durations']) / value['matches']:.1f} | {sum(value['deaths'].values())} | "
                     f"{value['deposits']} / {value['shards']} | [PNG]({filename}) |")
    lines += ["", "Красные клетки показывают число смертей; шкала цвета общая для всех карт. "
              "Стены и кусты показаны по исходной карте: в матче окружение может разрушаться.", "",
              "Исходные журналы: [20 JSON-файлов](match_logs/). Генерация и определения метрик — "
              "[`tools/match_log/README.md`](../../tools/match_log/README.md).", ""]
    (output / "match_stats.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"MATCH_STATS_OK {len(records)} matches, {len(maps)} maps")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    paths = sorted(args.logs.glob("match_*.json"))
    write_report([json.loads(path.read_text(encoding="utf-8")) for path in paths], args.output_dir)


if __name__ == "__main__":
    main()
