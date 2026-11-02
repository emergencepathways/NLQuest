#!/usr/bin/env python3
"""
Speurtocht.NL - build the quest catalog every batch is planned from.

Usage:
    python3 tools/build_catalog.py <world_full.sql> source/catalog.json

For each quest (patch 1.12 text) the catalog records:
    level, zone name, faction, dungeon (if any), category, English text, word count

Faction comes from who *gives* the quest, not only from the race mask: many
quests are open to "both" in the database but are only offered by Horde NPCs.
A creature faction template counts as Alliance or Horde when the database's
race-restricted quests show it only on one side.

Source: VMaNGOS world database, github.com/brotalnia/database
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_vanilla_quests import parse_values, TEXT_FIELDS, ALLIANCE_RACES, HORDE_RACES  # noqa: E402

ZONES = {
    1: "Dun Morogh", 3: "Badlands", 4: "Blasted Lands", 8: "Swamp of Sorrows", 9: "Northshire",
    10: "Duskwood", 11: "Wetlands", 12: "Elwynn Forest", 14: "Durotar", 15: "Dustwallow Marsh",
    16: "Azshara", 17: "The Barrens", 25: "Blackrock Mountain", 28: "Western Plaguelands",
    33: "Stranglethorn Vale", 36: "Alterac Mountains", 38: "Loch Modan", 40: "Westfall",
    41: "Deadwind Pass", 44: "Redridge Mountains", 45: "Arathi Highlands", 46: "Burning Steppes",
    47: "The Hinterlands", 51: "Searing Gorge", 85: "Tirisfal Glades", 130: "Silverpine Forest",
    132: "Coldridge Valley", 139: "Eastern Plaguelands", 141: "Teldrassil", 148: "Darkshore",
    154: "Deathknell", 188: "Shadowglen", 215: "Mulgore", 220: "Red Cloud Mesa", 267: "Hillsbrad Foothills",
    331: "Ashenvale", 357: "Feralas", 361: "Felwood", 363: "Valley of Trials", 400: "Thousand Needles",
    405: "Desolace", 406: "Stonetalon Mountains", 440: "Tanaris", 490: "Un'Goro Crater",
    493: "Moonglade", 618: "Winterspring", 1377: "Silithus", 1497: "Undercity", 1519: "Stormwind City",
    1537: "Ironforge", 1637: "Orgrimmar", 1638: "Thunder Bluff", 1657: "Darnassus", 2257: "Deeprun Tram",
    2597: "Alterac Valley", 3277: "Warsong Gulch", 3358: "Arathi Basin",
    0: "Miscellaneous", 24: "Northshire Abbey", 131: "Kharanos",
    # dungeons and raids (133/1517/1717 are the quest-log zones Blizzard used for these)
    133: "Gnomeregan", 1517: "Uldaman", 1717: "Razorfen Kraul",
    1581: "The Deadmines", 718: "Wailing Caverns", 209: "Shadowfang Keep", 719: "Blackfathom Deeps",
    717: "The Stockade", 721: "Gnomeregan", 491: "Razorfen Kraul", 796: "Scarlet Monastery",
    722: "Razorfen Downs", 1337: "Uldaman", 1176: "Zul'Farrak", 978: "Zul'Farrak", 2100: "Maraudon",
    1477: "Sunken Temple", 1417: "Sunken Temple", 1584: "Blackrock Depths", 1583: "Blackrock Spire",
    2557: "Dire Maul", 2057: "Scholomance", 2017: "Stratholme", 2437: "Ragefire Chasm",
    2717: "Molten Core", 2159: "Onyxia's Lair", 2677: "Blackwing Lair", 1977: "Zul'Gurub",
    3428: "Ahn'Qiraj", 3429: "Ruins of Ahn'Qiraj", 3456: "Naxxramas", 3478: "Gates of Ahn'Qiraj",
}
SORTS = {
    -61: "Warlock", -81: "Warrior", -82: "Shaman", -141: "Paladin", -161: "Mage", -162: "Rogue",
    -261: "Hunter", -262: "Priest", -263: "Druid",
    -24: "Herbalism", -101: "Fishing", -121: "Blacksmithing", -181: "Alchemy", -182: "Leatherworking",
    -201: "Engineering", -264: "Tailoring", -304: "Cooking", -324: "First Aid",
    -1: "Epic", -22: "Seasonal", -284: "Special", -364: "Darkmoon Faire", -365: "Ahn'Qiraj War",
    -366: "Lunar Festival", -367: "Reputation", -368: "Invasion", -369: "Midsummer", -25: "Battlegrounds",
    -221: "Treasure Map", -41: "Day of the Dead", -344: "Legendary", -241: "Tournament", -21: "Wintervale",
}
CLASS_SORTS = {-61, -81, -82, -141, -161, -162, -261, -262, -263}
PROFESSION_SORTS = {-24, -101, -121, -181, -182, -201, -264, -304, -324}
DUNGEON_MAPS = {36: "The Deadmines", 43: "Wailing Caverns", 33: "Shadowfang Keep", 48: "Blackfathom Deeps",
                34: "The Stockade", 90: "Gnomeregan", 47: "Razorfen Kraul", 189: "Scarlet Monastery",
                129: "Razorfen Downs", 70: "Uldaman", 209: "Zul'Farrak", 349: "Maraudon",
                109: "Sunken Temple", 230: "Blackrock Depths", 229: "Blackrock Spire", 429: "Dire Maul",
                289: "Scholomance", 329: "Stratholme", 389: "Ragefire Chasm"}
RAID_MAPS = {409: "Molten Core", 249: "Onyxia's Lair", 469: "Blackwing Lair", 309: "Zul'Gurub",
             509: "Ruins of Ahn'Qiraj", 531: "Ahn'Qiraj", 533: "Naxxramas"}
ATTUNEMENT = {7848, 7487, 4182, 4183, 4184, 4185, 4186, 4223, 4224, 4241, 4242, 4264, 4282, 4322,
              6402, 6403, 6501, 6502, 7761, 4742, 4743, 5092, 5097, 5533, 5537, 5538, 5505, 5511,
              3801, 3802, 6821}


def rows(sql, table):
    pat = re.compile(r"INSERT INTO `%s` \(([^)]*)\) VALUES" % table, re.S)
    for m in pat.finditer(sql):
        cols = [c.strip().strip("`") for c in m.group(1).split(",")]
        for r in parse_values(sql, m.end()):
            yield dict(zip(cols, r))


def latest(rs, key="entry", patch="patch"):
    out = {}
    for r in rs:
        if r.get(patch, 0) > 10:
            continue
        k = r[key]
        if k not in out or r.get(patch, 0) >= out[k].get(patch, 0):
            out[k] = r
    return out


def main(sql_path, out_path):
    sql = open(sql_path, encoding="utf-8", errors="replace").read()
    quests = latest(rows(sql, "quest_template"))
    ctempl = latest(rows(sql, "creature_template"))
    starters = defaultdict(set)
    for r in rows(sql, "creature_questrelation"):
        if r.get("patch_min", 0) <= 10:
            starters[r["quest"]].add(r["id"])

    # creature spawns -> maps, item drops -> creatures, for dungeon detection
    cre_maps, go_maps = defaultdict(set), defaultdict(set)
    for r in rows(sql, "creature"):
        for k in ("id", "id2", "id3", "id4"):
            if r.get(k):
                cre_maps[r[k]].add(r["map"])
    for r in rows(sql, "gameobject"):
        go_maps[r["id"]].add(r["map"])
    item_cre = defaultdict(set)
    for r in rows(sql, "creature_loot_template"):
        item_cre[r["item"]].add(r["entry"])

    def side_of_races(races):
        if races and not races & HORDE_RACES:
            return "alliance"
        if races and not races & ALLIANCE_RACES:
            return "horde"
        return "both"

    # learn which faction templates belong to which side
    seen = defaultdict(Counter)
    for qid, q in quests.items():
        s = side_of_races(q["RequiredRaces"] or 0)
        if s == "both":
            continue
        for npc in starters.get(qid, ()):
            if npc in ctempl:
                seen[ctempl[npc]["faction"]][s] += 1
    template_side = {}
    for fac, c in seen.items():
        if c["alliance"] and not c["horde"]:
            template_side[fac] = "alliance"
        elif c["horde"] and not c["alliance"]:
            template_side[fac] = "horde"

    def source_maps(q):
        maps = set()
        for i in range(1, 5):
            c = q.get("ReqCreatureOrGOId%d" % i) or 0
            if c > 0:
                maps |= cre_maps.get(c, set())
            elif c < 0:
                maps |= go_maps.get(-c, set())
            item = q.get("ReqItemId%d" % i) or 0
            for cre in item_cre.get(item, ()) if item else ():
                maps |= cre_maps.get(cre, set())
        return maps

    catalog = {}
    for qid, q in sorted(quests.items()):
        side = side_of_races(q["RequiredRaces"] or 0)
        givers = [ctempl[n] for n in starters.get(qid, ()) if n in ctempl]
        if side == "both" and givers:
            sides = {template_side.get(g["faction"], "neutral") for g in givers}
            if sides == {"horde"}:
                side = "horde"
            elif sides == {"alliance"}:
                side = "alliance"
        zone = q["ZoneOrSort"]
        name = ZONES.get(zone) or SORTS.get(zone) or "zone %d" % zone
        category = ("class" if zone in CLASS_SORTS else "profession" if zone in PROFESSION_SORTS
                    else "other" if zone < 0 else "zone")
        dungeon = None
        if name in DUNGEON_MAPS.values() and zone > 0:
            dungeon = name
        else:
            maps = source_maps(q)
            if maps and maps <= set(DUNGEON_MAPS):
                dungeon = DUNGEON_MAPS[sorted(maps)[0]]
            elif maps and maps <= set(RAID_MAPS):
                dungeon = RAID_MAPS[sorted(maps)[0]]
        if qid in ATTUNEMENT:
            category = "attunement"
        elif dungeon:
            category = "dungeon"
        en = {k: q[k] for k in TEXT_FIELDS if q.get(k)}
        catalog[str(qid)] = {
            "level": q["QuestLevel"], "min": q["MinLevel"], "zone": name, "side": side,
            "category": category, "dungeon": dungeon,
            "giver": givers[0]["name"] if givers else None,
            "words": sum(len(str(v).split()) for v in en.values()),
            "en": en,
        }
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(catalog, fh, ensure_ascii=False, indent=0, sort_keys=True)
    c = Counter(v["side"] for v in catalog.values())
    print("%d quests -> %s  (%s)" % (len(catalog), out_path, ", ".join("%s %d" % kv for kv in c.items())))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
