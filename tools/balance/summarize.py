#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Агрегация CSV из run_matches.gd в markdown-таблицы для docs/balance/report.md.

Запуск: python tools/balance/summarize.py <results.csv>
"""
import statistics
import sys
from collections import defaultdict

HEROES = ["lynx", "anvil", "shishka"]
SIDE_LIMIT = 58.0
DOMINANCE = 60.0


def read_rows(path):
    with open(path, encoding="utf-8") as f:
        header = f.readline().strip().split(",")
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            parts += [""] * (len(header) - len(parts))
            yield dict(zip(header, parts))


def side_heroes(r):
    """Герои на стороне 0 и стороне 1 с учётом смены сторон."""
    if r["swap"] == "1":
        return r["hero2"], r["hero1"]
    return r["hero1"], r["hero2"]


def main():
    rows = list(read_rows(sys.argv[1]))
    duels = [r for r in rows if r["kind"] == "duel"]
    teams = [r for r in rows if r["kind"] == "team"]

    win = defaultdict(lambda: [0, 0])          # (герой, враг) -> [победы, дуэлей]
    ttk = defaultdict(list)                    # (герой0, герой1) -> секунды до убийства
    timeouts = defaultdict(int)
    mirror_hits = defaultdict(list)            # герой -> попадания победителя в зеркале
    st = defaultdict(lambda: {"shots": 0, "hits": 0, "supers": 0, "min": 0.0})
    for r in duels:
        s0, s1 = side_heroes(r)
        for side, hero in ((0, s0), (1, s1)):
            h, col = st[hero], "1" if side == 0 else "2"
            h["shots"] += int(r["shots" + col] or 0)
            h["hits"] += int(r["hits" + col] or 0)
            h["supers"] += int(r["supers" + col] or 0)
            h["min"] += float(r["duration_sec"] or 0) / 60.0
        w = int(r["winner"])
        if w == -1:
            timeouts[(s0, s1)] += 1
            continue
        win_h, lose_h = (s0, s1) if w == 0 else (s1, s0)
        win[(win_h, lose_h)][0] += 1
        for pair in ((win_h, lose_h), (lose_h, win_h)):
            win[pair][1] += 1
        if r["ttk_sec"]:
            ttk[(s0, s1)].append(float(r["ttk_sec"]))
        if s0 == s1:
            mirror_hits[s0].append(int(r["hits1" if w == 0 else "hits2"]))

    def rate(a, b):
        w, g = win.get((a, b), [0, 0])
        return 100.0 * w / g if g else float("nan")

    print("## Дуэли 1v1\n")
    print("Матрица: % побед героя из строки против героя из столбца (все карты, N дуэлей на клетку)\n")
    print("| герой | " + " | ".join(HEROES) + " | vs остальным |")
    print("|---|" + "---|" * (len(HEROES) + 1))
    for a in HEROES:
        cells, tot_w, tot_g = [], 0, 0
        for b in HEROES:
            if a == b:
                cells.append("—")
                continue
            w, g = win.get((a, b), [0, 0])
            tot_w, tot_g = tot_w + w, tot_g + g
            cells.append("%.0f%% (%d)" % (rate(a, b), g))
        cells.append("**%.0f%%**" % (100.0 * tot_w / tot_g if tot_g else float("nan")))
        print("| %s | %s |" % (a, " | ".join(cells)))
    dominated = []
    for h in HEROES:
        tw = sum(win.get((h, o), [0, 0])[0] for o in HEROES if o != h)
        tg = sum(win.get((h, o), [0, 0])[1] for o in HEROES if o != h)
        if tg and 100.0 * tw / tg > DOMINANCE:
            print("\n!!! %s выигрывает %.0f%% против остальных (порог %.0f%%)" % (h, 100.0 * tw / tg, DOMINANCE))

    print("\n## TTK и таймауты дуэлей (по парам, все карты)\n")
    print("| пара | TTK, с (медиана) | таймаутов |")
    print("|---|---|---|")
    seen = set()
    for a in HEROES:
        for b in HEROES:
            key = tuple(sorted((a, b)))
            if key in seen:
                continue
            seen.add(key)
            times = ttk.get((a, b), []) + ttk.get((b, a), [])
            to = timeouts.get((a, b), 0) + timeouts.get((b, a), 0)
            med = "%.1f" % statistics.median(times) if times else "—"
            print("| %s vs %s | %s | %d |" % (a, b, med, to))

    print("\n## Зеркальные дуэли: сколько попаданий победителя решало бой\n")
    print("| герой | медиана попаданий | дуэлей быстрее 3 попаданий |")
    print("|---|---|---|")
    for h in HEROES:
        vals = mirror_hits.get(h, [])
        if not vals:
            continue
        fast = sum(1 for v in vals if v < 3)
        print("| %s | %.1f | %d из %d |" % (h, statistics.median(vals), fast, len(vals)))

    print("\n## Точность и суперы (дуэли)\n")
    print("| герой | попаданий на выстрел | суперов в минуту |")
    print("|---|---|---|")
    for h in HEROES:
        s = st[h]
        acc = s["hits"] / s["shots"] if s["shots"] else float("nan")
        spm = s["supers"] / s["min"] if s["min"] else float("nan")
        print("| %s | %.2f | %.1f |" % (h, acc, spm))

    print("\n## Баланс сторон в 3v3\n")
    print("| режим | карта | побед стороны 1 | стороны 2 | ничьих | перевес стороны |")
    print("|---|---|---|---|---|---|")
    side = defaultdict(lambda: [0, 0, 0])
    scores = defaultdict(lambda: [0, 0])
    for r in teams:
        key = (r["mode"], r["map"])
        w = int(r["winner"])
        side[key][w if w >= 0 else 2] += 1
        scores[key][0] += int(r["score1"] or 0)
        scores[key][1] += int(r["score2"] or 0)
    for (mode, m), (w0, w1, dr) in sorted(side.items()):
        decided = w0 + w1
        p0 = 100.0 * w0 / decided if decided else float("nan")
        heavy = " !!! >%d%%" % SIDE_LIMIT if decided and max(p0, 100 - p0) > SIDE_LIMIT else ""
        print("| %s | %s | %d (%.0f%%) | %d (%.0f%%) | %d | %.0f%%%s |" % (
            mode, m, w0, p0, w1, 100.0 - p0, dr, max(p0, 100.0 - p0), heavy))
    print("\nСредний счёт: " + "; ".join(
        "%s/%s %.1f:%.1f" % (k[0], k[1], v[0] / 30.0, v[1] / 30.0) for k, v in sorted(scores.items())))


if __name__ == "__main__":
    main()
