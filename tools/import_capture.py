#!/usr/bin/env python3
"""
Speurtocht.NL - add quests recorded in game (WoW Forever) to the translation plan.

Usage (from the repo root):
    python3 tools/import_capture.py <capture> [<capture> ...]

Each <capture> is either a SavedVariables file (WTF/Account/<ACCOUNT>/SavedVariables/
SpeurtochtNL.lua, straight from the game folder) or a captured.json made by
tools/capture_to_json.py (for example one attached to a "Missing quest" issue).
Several files from several players or characters can be given at once.

What it does:
1. New quests (no Dutch translation, not in the catalog) go into source/catalog.json
   with category "forever". The client has already filled in the player's name,
   class and race, so those are turned back into $n $c $r.
2. They are cut into new batches (~4,000 English words, per faction and zone) that
   are appended to source/batches.json after the last batch. Existing batches keep
   their numbers, so this is safe while other batches are in flight.
   The normal lanes then pick them up: "Next batch, alliance lane." / "... horde lane."
3. Translated quests whose English text changed in Forever get their catalog text
   updated and are listed in work/forever_changed.txt with the batch file to fix.

Then commit the catalog and plan on a branch named forever-capture-<date> and merge it
(see docs/WORKFLOW.md, "WoW Forever: captured quests").
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from plan_batches import translated_ids, slug  # noqa: E402
from savedvars import load  # noqa: E402

CAPTURE_FIELDS = {"title": "Title", "desc": "Details", "obj": "Objectives",
                  "progress": "RequestItemsText", "reward": "OfferRewardText"}
EN_FIELDS = ("Title", "Details", "Objectives", "RequestItemsText", "OfferRewardText")
LIMIT = 4000


def unsubstitute(text, who):
    """Put $n $c $r back where the client wrote the player's own name, class and race."""
    if not text:
        return text
    text = text.replace("\r\n", "\n")
    for value, ph in ((who.get("pname"), "$n"), (who.get("prace"), "$r"), (who.get("pclass"), "$c")):
        if not value or len(value) < 3:
            continue
        flags = 0 if ph == "$n" else re.IGNORECASE
        text = re.sub(r"(?<![\w$])%s(?!\w)" % re.escape(value), ph, text, flags=flags)
    return text


def read_capture(path):
    """-> (new, changed): {qid: entry} with English under "en" and the player context."""
    if path.endswith(".json"):
        data = json.load(open(path, encoding="utf-8"))
        def norm(store):
            out = {}
            for qid, e in store.items():
                flat = {k: v for k, v in e.items() if k != "en"}
                for short, long_ in CAPTURE_FIELDS.items():
                    if (e.get("en") or {}).get(long_):
                        flat[short] = e["en"][long_]
                out[qid] = flat
            return out
        return norm(data.get("new") or {}), norm(data.get("changed") or {})
    cap = load(path).get("SpeurtochtNLCapture") or {}
    return cap.get("quests") or {}, cap.get("changed") or {}


def english(entry):
    en = {}
    for short, long_ in CAPTURE_FIELDS.items():
        v = unsubstitute(entry.get(short), entry)
        if v:
            en[long_] = v
    return en


def side_of(entry):
    f = (entry.get("faction") or "").lower()
    return f if f in ("alliance", "horde") else "both"


def main():
    paths = sys.argv[1:]
    if not paths:
        sys.exit(__doc__)
    cat_path = os.path.join(ROOT, "source", "catalog.json")
    plan_path = os.path.join(ROOT, "source", "batches.json")
    catalog = json.load(open(cat_path, encoding="utf-8"))
    plan = json.load(open(plan_path, encoding="utf-8"))
    done = translated_ids()
    planned = {q for b in plan["batches"] for q in b["quests"]}

    added, merged, changed, skipped = [], [], {}, []
    for path in paths:
        new, chg = read_capture(path)
        for raw_id, e in new.items():
            if not str(raw_id).isdigit():
                skipped.append("%s (no quest ID)" % raw_id)
                continue
            qid = int(raw_id)
            en = english(e)
            if not en.get("Title"):
                skipped.append("%d (no title)" % qid)
                continue
            if qid in done:
                continue                      # translated in the meantime
            key = str(qid)
            if key in catalog:
                # seen before (another capture file): fill in fields this one has extra
                old = catalog[key]["en"]
                extra = {k: v for k, v in en.items() if k not in old}
                if extra:
                    old.update(extra)
                    catalog[key]["words"] = sum(len(str(v).split()) for v in old.values())
                    merged.append(qid)
                continue
            level = e.get("level") or e.get("plevel") or 1
            catalog[key] = {
                "category": "forever", "dungeon": None, "en": en,
                "giver": e.get("npc"), "level": int(level), "min": None,
                "next": None, "prev": None, "side": side_of(e),
                "words": sum(len(str(v).split()) for v in en.values()),
                "zone": e.get("zone") or "Unknown zone",
            }
            added.append(qid)
        for raw_id, e in chg.items():
            if not str(raw_id).isdigit() or str(raw_id) not in catalog:
                continue
            en = english(e)
            old = catalog[str(raw_id)]["en"]
            diff = {k: v for k, v in en.items() if v and old.get(k) and v.strip() != old[k].strip()}
            if diff:
                changed[int(raw_id)] = (dict(old), diff)
                old.update(diff)

    # Plan: every captured quest that isn't translated or planned yet, per faction and zone.
    todo = sorted((int(k) for k, v in catalog.items()
                   if v["category"] == "forever" and int(k) not in done and int(k) not in planned),
                  key=lambda i: (catalog[str(i)]["side"], catalog[str(i)]["zone"], catalog[str(i)]["level"], i))
    groups = {}
    for i in todo:
        q = catalog[str(i)]
        groups.setdefault((q["side"], q["zone"]), []).append(i)
    order = sorted(groups, key=lambda g: (min(catalog[str(i)]["level"] for i in groups[g]), g))
    new_batches, cur, words, names = [], [], 0, []

    def flush():
        nonlocal cur, words, names
        if cur:
            new_batches.append({"quests": cur, "words": words,
                                "name": "Forever: " + " + ".join(dict.fromkeys(names))})
        cur, words, names = [], 0, []

    last_side = None
    for side, zone in order:
        if side != last_side:            # keep lanes apart: never mix Alliance and Horde
            flush()
            last_side = side
        for i in groups[(side, zone)]:
            w = catalog[str(i)]["words"]
            if cur and words + w > LIMIT:
                flush()
            cur.append(i)
            words += w
            names.append(zone)
        if words > LIMIT * 0.6:
            flush()
    flush()
    start = max(b["n"] for b in plan["batches"]) + 1
    for n, b in enumerate(new_batches, start):
        b["n"] = n
        b["slug"] = ("%02d-forever-%s" % (n, slug(b["name"][len("Forever: "):].split(" + ")[0])))[:40]
    plan["batches"].extend(new_batches)

    json.dump(catalog, open(cat_path, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    json.dump(plan, open(plan_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    if changed:
        files = glob.glob(os.path.join(ROOT, "batches", "*.json"))
        where = {}
        for f in files:
            for qid in json.load(open(f, encoding="utf-8")).get("quests", {}):
                where[int(qid)] = os.path.relpath(f, ROOT)
        for f in glob.glob(os.path.join(ROOT, "Data", "*.lua")):   # quests with no batch JSON
            for qid in re.findall(r"^\[(\d+)\]\s*=\s*\{", open(f, encoding="utf-8").read(), re.M):
                where.setdefault(int(qid), os.path.relpath(f, ROOT))
        lines = ["# Translated quests whose English text changed in Forever.",
                 "# Update the Dutch in the batch file named on each quest, then import that batch.", ""]
        for qid, (old, diff) in sorted(changed.items()):
            lines.append("### %d  %s  -> %s" % (qid, old.get("Title", "?"), where.get(qid, "?")))
            for k, v in diff.items():
                lines.append("[%s, was] %s" % (k, old.get(k, "").replace("\n", "$b")))
                lines.append("[%s, now] %s" % (k, v.replace("\n", "$b")))
            lines.append("")
        os.makedirs(os.path.join(ROOT, "work"), exist_ok=True)
        open(os.path.join(ROOT, "work", "forever_changed.txt"), "w", encoding="utf-8").write("\n".join(lines))

    print("%d new quests added to the catalog, %d completed from another capture" % (len(added), len(merged)))
    for b in new_batches:
        print("  batch %3d  %3d quests %5d words  %s" % (b["n"], len(b["quests"]), b["words"], b["name"]))
    if changed:
        print("%d translated quests changed in Forever -> work/forever_changed.txt" % len(changed))
    if skipped:
        print("skipped: " + ", ".join(skipped))
    if not added and not merged and not changed:
        print("nothing new in the capture")


if __name__ == "__main__":
    main()
