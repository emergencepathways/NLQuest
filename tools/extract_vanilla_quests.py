#!/usr/bin/env python3
"""
SpeurtochtNL - extract English quest text from a VMaNGOS world database dump.

Source: https://github.com/brotalnia/database  (world_full_*.7z -> .sql)

Usage:
    python3 extract_vanilla_quests.py world_full_14_june_2021.sql quests_en.json

Writes one JSON object keyed by quest ID with the English text fields the
addon translates, plus metadata (level, zone, races) used for planning batches
and choosing the Dutch difficulty tier.

For each quest the highest patch row (<= 10, i.e. patch 1.12) is kept, which
matches the text Classic Era / Forever shipped with.
"""
import json
import re
import sys

ALLIANCE_RACES = 1 | 4 | 8 | 64      # Human, Dwarf, Night Elf, Gnome
HORDE_RACES = 2 | 16 | 32 | 128      # Orc, Undead, Tauren, Troll

TEXT_FIELDS = ["Title", "Details", "Objectives", "OfferRewardText",
               "RequestItemsText", "EndText",
               "ObjectiveText1", "ObjectiveText2", "ObjectiveText3", "ObjectiveText4"]
META_FIELDS = ["entry", "patch", "ZoneOrSort", "MinLevel", "QuestLevel",
               "RequiredRaces", "RequiredClasses", "PrevQuestId", "NextQuestInChain",
               "Type", "SuggestedPlayers"]


def parse_values(blob, start):
    """Yield tuples (as python lists) from a VALUES (...),(...); block."""
    i, n = start, len(blob)
    while i < n:
        while i < n and blob[i] in " \n\r\t,":
            i += 1
        if i >= n or blob[i] == ";":
            return i
        if blob[i] != "(":
            raise ValueError("unexpected char %r at %d" % (blob[i], i))
        i += 1
        row, cur, in_str = [], [], False
        while True:
            c = blob[i]
            if in_str:
                if c == "\\":
                    nxt = blob[i + 1]
                    cur.append({"n": "\n", "r": "\r", "t": "\t", "0": ""}.get(nxt, nxt))
                    i += 2
                    continue
                if c == "'":
                    if blob[i + 1] == "'":
                        cur.append("'")
                        i += 2
                        continue
                    in_str = False
                    i += 1
                    continue
                cur.append(c)
                i += 1
                continue
            if c == "'":
                in_str = True
                cur.append("\x00STR")  # marker so empty strings stay strings
                i += 1
            elif c == ",":
                row.append("".join(cur))
                cur = []
                i += 1
            elif c == ")":
                row.append("".join(cur))
                i += 1
                break
            else:
                if not c.isspace():
                    cur.append(c)
                i += 1
        yield [convert(v) for v in row]


def convert(v):
    if v.startswith("\x00STR"):
        return v[4:]
    v = v.strip()
    if v.upper() == "NULL":
        return None
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return v


def main(sql_path, out_path):
    with open(sql_path, encoding="utf-8", errors="replace") as fh:
        sql = fh.read()
    quests = {}
    pat = re.compile(r"INSERT INTO `quest_template` \(([^)]*)\) VALUES", re.S)
    for m in pat.finditer(sql):
        cols = [c.strip().strip("`") for c in m.group(1).split(",")]
        gen = parse_values(sql, m.end())
        for row in gen:
            rec = dict(zip(cols, row))
            if rec["patch"] > 10:
                continue
            qid = rec["entry"]
            prev = quests.get(qid)
            if prev is None or rec["patch"] >= prev["patch"]:
                quests[qid] = rec
    out = {}
    for qid, rec in sorted(quests.items()):
        races = rec["RequiredRaces"] or 0
        side = "both"
        if races and not races & HORDE_RACES:
            side = "alliance"
        elif races and not races & ALLIANCE_RACES:
            side = "horde"
        item = {k: rec[k] for k in META_FIELDS}
        item["side"] = side
        item["en"] = {k: rec[k] for k in TEXT_FIELDS if rec.get(k)}
        out[str(qid)] = item
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
    print("wrote %d quests to %s" % (len(out), out_path))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
