#!/usr/bin/env python3
"""
SpeurtochtNL - decide which quests belong to each translation batch.

Usage:
    python3 build_manifest.py world_full.sql quests_en.json manifest.json

A quest is tagged as a *dungeon quest* when its quest-log zone is a dungeon,
or when every known source of its objectives (creatures to kill, objects to
use, items to loot) spawns inside a dungeon map. The second rule catches the
many dungeon quests Blizzard filed under an outdoor zone (Gnomeregan quests
under Dun Morogh, Uldaman under Badlands, and so on).

Batches written to the manifest:
    v1-start-<zone>     Alliance starting-zone quests (+ low-level class quests)
    v1-dungeon-<name>   Alliance-available 5-player dungeon quests, levels 10-60
    v1-attunement       Raid / key attunement chains
    later-alliance      Every other Alliance-available quest
    later-horde         Horde-only quests
"""
import json
import re
import sys
from collections import defaultdict

sys.path.insert(0, __import__("os").path.dirname(__file__))
from extract_vanilla_quests import parse_values  # noqa: E402

DUNGEON_MAPS = {
    36: "Deadmines", 43: "Wailing Caverns", 33: "Shadowfang Keep",
    48: "Blackfathom Deeps", 34: "Stormwind Stockade", 90: "Gnomeregan",
    47: "Razorfen Kraul", 189: "Scarlet Monastery", 129: "Razorfen Downs",
    70: "Uldaman", 209: "Zul'Farrak", 349: "Maraudon", 109: "Sunken Temple",
    230: "Blackrock Depths", 229: "Blackrock Spire", 429: "Dire Maul",
    289: "Scholomance", 329: "Stratholme",
}
RAID_MAPS = {409: "Molten Core", 249: "Onyxia's Lair", 469: "Blackwing Lair",
             309: "Zul'Gurub", 509: "Ruins of Ahn'Qiraj", 531: "Ahn'Qiraj", 533: "Naxxramas"}
DUNGEON_ZONES = {
    1581: "Deadmines", 718: "Wailing Caverns", 209: "Shadowfang Keep",
    719: "Blackfathom Deeps", 717: "Stormwind Stockade", 721: "Gnomeregan",
    491: "Razorfen Kraul", 796: "Scarlet Monastery", 722: "Razorfen Downs",
    1337: "Uldaman", 1176: "Zul'Farrak", 2100: "Maraudon", 1477: "Sunken Temple",
    1417: "Sunken Temple", 1584: "Blackrock Depths", 1583: "Blackrock Spire",
    2557: "Dire Maul", 2057: "Scholomance", 2017: "Stratholme",
}
START_ZONES = {132: "coldridge", 1: "dunmorogh", 9: "northshire", 12: "elwynn",
               188: "shadowglen", 141: "teldrassil"}
# Attunement and dungeon-key chains (Alliance side or neutral)
ATTUNEMENT = [
    7848, 7487,                      # Attunement to the Core (Molten Core)
    4182, 4183, 4184, 4185, 4186, 4223, 4224, 4241, 4242, 4264, 4282,
    4322, 6402, 6403, 6501, 6502,    # Onyxia (Alliance: Dragonkin Menace -> Drakefire Amulet)
    7761,                            # Blackhand's Command (Blackwing Lair)
    4742, 4743,                      # Seal of Ascension (Upper Blackrock Spire)
    5092, 5097, 5533, 5537, 5538, 5505, 5511,  # Scholomance key chain (Alliance)
    3801, 3802,                      # Shadowforge Key (Dark Iron Legacy)
    6821,                            # Eye of the Emberseer (Hydraxian Waterlords)
]


def load_rows(sql, table):
    pat = re.compile(r"INSERT INTO `%s` \(([^)]*)\) VALUES" % table, re.S)
    for m in pat.finditer(sql):
        cols = [c.strip().strip("`") for c in m.group(1).split(",")]
        for row in parse_values(sql, m.end()):
            yield dict(zip(cols, row))


def main(sql_path, quests_path, out_path):
    sql = open(sql_path, encoding="utf-8", errors="replace").read()
    quests = json.load(open(quests_path, encoding="utf-8"))

    cre_maps, go_maps = defaultdict(set), defaultdict(set)
    for r in load_rows(sql, "creature"):
        for k in ("id", "id2", "id3", "id4"):
            if r.get(k):
                cre_maps[r[k]].add(r["map"])
    for r in load_rows(sql, "gameobject"):
        go_maps[r["id"]].add(r["map"])
    item_from_cre, item_from_go = defaultdict(set), defaultdict(set)
    for r in load_rows(sql, "creature_loot_template"):
        item_from_cre[r["item"]].add(r["entry"])
    go_loot = {}
    for r in load_rows(sql, "gameobject_template"):
        if r["type"] == 3 and r.get("data1"):
            go_loot.setdefault(r["data1"], set()).add(r["entry"])
    for r in load_rows(sql, "gameobject_loot_template"):
        for go in go_loot.get(r["entry"], ()):
            item_from_go[r["item"]].add(go)

    # objective ids need the raw table again (extractor keeps text only)
    objectives = {}
    for r in load_rows(sql, "quest_template"):
        objectives[str(r["entry"])] = r

    def source_maps(qid):
        r = objectives.get(qid)
        if not r:
            return set()
        maps = set()
        for i in range(1, 5):
            c = r.get("ReqCreatureOrGOId%d" % i) or 0
            if c > 0:
                maps |= cre_maps.get(c, set())
            elif c < 0:
                maps |= go_maps.get(-c, set())
            item = r.get("ReqItemId%d" % i) or 0
            if item:
                for cre in item_from_cre.get(item, ()):
                    maps |= cre_maps.get(cre, set())
                for go in item_from_go.get(item, ()):
                    maps |= go_maps.get(go, set())
        return maps

    batches = defaultdict(list)
    for qid, q in quests.items():
        if q["side"] == "horde":
            batches["later-horde"].append(int(qid))
            continue
        zone, lvl = q["ZoneOrSort"], q["QuestLevel"]
        if int(qid) in ATTUNEMENT:
            batches["v1-attunement"].append(int(qid))
            continue
        if zone in START_ZONES:
            batches["v1-start-" + START_ZONES[zone]].append(int(qid))
            continue
        if zone < 0 and lvl <= 10:
            batches["v1-start-classquests"].append(int(qid))
            continue
        dname = DUNGEON_ZONES.get(zone)
        if not dname:
            maps = source_maps(qid)
            if maps and maps <= set(DUNGEON_MAPS):
                dname = DUNGEON_MAPS[sorted(maps)[0]]
        if dname and lvl >= 10:
            slug = re.sub(r"[^a-z]", "", dname.lower())
            batches["v1-dungeon-" + slug].append(int(qid))
            continue
        batches["later-alliance"].append(int(qid))

    out = {k: sorted(v) for k, v in sorted(batches.items())}
    json.dump(out, open(out_path, "w"), indent=1)
    for k, v in out.items():
        print("%-32s %4d" % (k, len(v)))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
