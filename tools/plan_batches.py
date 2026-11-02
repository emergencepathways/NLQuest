#!/usr/bin/env python3
"""
Speurtocht.NL - turn route.txt into numbered translation batches.

Usage (from the repo root):
    python3 tools/plan_batches.py            write source/batches.json and print the plan
    python3 tools/plan_batches.py --words 4000

Rules
- Only quests an Alliance character can get (catalog side alliance/both).
- Quests already in Data/*.lua are marked done and never planned again.
- A batch holds up to ~4,000 English words (one work session, safe for one
  Claude turn). Big zones are split by quest level; chains stay in order.
- A line ending in "*" collects everything not yet planned (catch-all).
- Batch numbers are stable: finished batches keep their number; only the
  unfinished part of the plan is renumbered.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "source", "catalog.json")
OUT = os.path.join(ROOT, "source", "batches.json")


def translated_ids():
    ids = set()
    for path in glob.glob(os.path.join(ROOT, "Data", "*.lua")):
        ids |= {int(x) for x in re.findall(r"^\[(\d+)\]\s*=\s*\{", open(path, encoding="utf-8").read(), re.M)}
    return ids


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def parse_route(path):
    max_level, entries = 60, []
    faction = "alliance"
    for raw in open(path, encoding="utf-8"):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("max-level:"):
            max_level = int(line.split(":", 1)[1])
            entries.append(("set-level", None, max_level, False))
            continue
        if line.startswith("faction:"):
            faction = line.split(":", 1)[1].strip().lower()
            entries.append(("set-faction", faction, None, False))
            continue
        pre = line.endswith("+pre")
        if pre:
            line = line[:-4].strip()
        cap = None
        if "@" in line:
            line, cap = [x.strip() for x in line.split("@", 1)]
            cap = int(cap)
        kind, name = "zone", line
        m = re.match(r"(class|profession|dungeon|other|forever):\s*(.+)", line)
        if m:
            kind, name = m.group(1), m.group(2).strip()
        entries.append((kind, name, cap, pre))
    return max_level, entries


def matches(q, kind, name):
    if kind == "dungeon":
        return q["dungeon"] == name and q["category"] in ("dungeon", "attunement")
    if kind == "zone":
        return q["zone"] == name and q["category"] == "zone"
    if kind == "class":
        return q["category"] == "class" and q["zone"] == name
    if kind == "profession":
        return q["category"] == "profession" and q["zone"] == name
    return q["category"] in ("other",) and q["zone"] == name


def main():
    limit = 4000
    if "--words" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--words") + 1])
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    done = translated_ids()
    _, route = parse_route(os.path.join(ROOT, "route.txt"))
    max_level = max([e[2] for e in route if e[0] == "set-level"] or [60])
    old = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {"batches": []}
    finished = [b for b in old["batches"] if all(q in done for q in b["quests"])]

    planned = set(done)
    for b in finished:
        planned |= set(b["quests"])
    pool = {int(k): v for k, v in catalog.items() if int(k) not in planned}
    level_cap, faction = 60, "alliance"

    def for_faction(q):
        return q["side"] in (faction, "both", "neutral")

    batches, cur, cur_words, cur_names = [], [], 0, []

    def flush():
        nonlocal cur, cur_words, cur_names
        if cur:
            batches.append({"quests": cur, "words": cur_words, "name": " + ".join(dict.fromkeys(cur_names))})
        cur, cur_words, cur_names = [], 0, []

    # quest -> quests that must be done before it (PrevQuestId, or another quest's NextQuestInChain)
    before = {}
    for k, v in catalog.items():
        if v.get("prev"):
            before.setdefault(int(k), set()).add(v["prev"])
        if v.get("next"):
            before.setdefault(v["next"], set()).add(int(k))

    def prerequisites(ids):
        found, todo = set(), list(ids)
        while todo:
            for p in before.get(todo.pop(), ()):
                if p in pool and p not in found and p not in ids:
                    found.add(p)
                    todo.append(p)
        return found

    capture_only = []
    for kind, name, cap, pre in route:
        if kind == "set-level":
            level_cap = cap
            continue
        if kind == "set-faction":
            faction = name
            continue
        if kind == "forever":
            capture_only.append(name)
            continue
        if name == "*":
            picked = [i for i, q in pool.items() if for_faction(q) and q["level"] <= level_cap]
            zone_start = {}
            for i in picked:
                zone_start[pool[i]["zone"]] = min(zone_start.get(pool[i]["zone"], 99), pool[i]["level"])
            picked.sort(key=lambda i: (zone_start[pool[i]["zone"]], pool[i]["zone"], pool[i]["level"], i))
            label = None
        else:
            picked = [i for i, q in pool.items() if matches(q, kind, name) and for_faction(q)
                      and q["level"] <= level_cap and (cap is None or q["level"] <= cap)]
            label = name if kind in ("zone", "dungeon") else "%s %s" % (kind, name)
            if cap:
                label += " ≤%d" % cap
        if pre:
            extra = prerequisites(set(picked))
            label += " (+%d voorquests)" % len(extra) if extra else ""
            picked = sorted(extra, key=lambda i: (pool[i]["level"], i)) + sorted(picked, key=lambda i: (pool[i]["level"], i))
        elif name != "*":
            picked.sort(key=lambda i: (pool[i]["level"], i))
        for i in picked:
            w = pool[i]["words"]
            if cur and cur_words + w > limit:
                flush()
            cur.append(i)
            cur_words += w
            cur_names.append(label or pool[i]["zone"])
            del pool[i]
        # start each zone with a fresh batch when the current one is already well filled
        if cur_words > limit * 0.6:
            flush()
    flush()

    start = (max(b["n"] for b in finished) + 1) if finished else 2
    for n, b in enumerate(batches, start):
        b["n"] = n
        b["slug"] = "%02d-%s" % (n, slug(b["name"].split(" + ")[0]))[:40]
    plan = {"limit": limit, "max_level": max_level, "batches": finished + batches, "capture_only": capture_only}
    json.dump(plan, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    total_q = sum(len(b["quests"]) for b in batches)
    total_w = sum(b["words"] for b in batches)
    print("%d translated, %d finished batches; %d quests (%d words) left in %d batches -> %s" % (
        len(done), len(finished), total_q, total_w, len(batches), os.path.relpath(OUT, ROOT)))
    for b in batches[:400]:
        print("  %3d  %4d quests %6d words  %s" % (b["n"], len(b["quests"]), b["words"], b["name"]))
    if capture_only:
        print("Forever-only, translated after in-game capture: " + ", ".join(capture_only))


if __name__ == "__main__":
    main()
