#!/usr/bin/env python3
"""
Speurtocht.NL - print the English source text for a batch, compactly.

Usage (from the repo root):
    python3 tools/next_batch.py                  the first unfinished batch
    python3 tools/next_batch.py --lane alliance  next batch for the Alliance lane
    python3 tools/next_batch.py --lane horde     next batch for the Horde lane
    python3 tools/next_batch.py 7                batch 7

Lanes let two work sessions run at the same time without picking the same batch:
- horde lane: batches with no Alliance-only quests (the Horde part of the route),
  in order. When those are done it helps out from the END of the Alliance lane.
- alliance lane: every other batch, in order from the front.
Batches that already have a batch-NN branch on GitHub but aren't on main yet
are "in flight" (another session or the auto-merge is busy with them) and are
skipped, so the lanes never collide.

Writes work/batch_NN.txt (not committed) and prints where it is plus a short
summary. The translator reads that file and writes batches/NN-<slug>.json
(format in docs/WORKFLOW.md), then runs tools/import_batch.py NN.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from plan_batches import translated_ids  # noqa: E402

FIELD_ORDER = [("Title", "t"), ("Details", "d"), ("Objectives", "o"), ("RequestItemsText", "p"),
               ("OfferRewardText", "c"), ("EndText", "e"),
               ("ObjectiveText1", "o1"), ("ObjectiveText2", "o2"), ("ObjectiveText3", "o3"), ("ObjectiveText4", "o4")]


def tier(level):
    # Same for Alliance and Horde: difficulty follows quest level only (docs/STYLE.md).
    # 1 = A1-A2 (1-20), 2 = A2-A2+ (21-35), 3 = A2-B1 (36-45), 4 = B1-B2 (46-60). Never above B2.
    return 1 if level <= 20 else 2 if level <= 35 else 3 if level <= 45 else 4


def lane_of(batch, catalog):
    sides = {catalog[str(q)]["side"] for q in batch["quests"]}
    return "horde" if "alliance" not in sides and "horde" in sides else "alliance"


def remote_batch_branches():
    """Batch numbers that have a batch-NN branch on GitHub (None if git can't reach it)."""
    try:
        out = subprocess.run(["git", "ls-remote", "--heads", "origin", "batch-*"], cwd=ROOT,
                             capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode:
        return None
    return {int(m) for m in re.findall(r"refs/heads/batch-(\d+)\s*$", out.stdout, re.M)}


def pick(plan, catalog, done, lane):
    todo = [b for b in plan["batches"] if not all(q in done for q in b["quests"])]
    pushed = remote_batch_branches()
    if pushed is None:
        print("warning: couldn't list GitHub branches; in-flight batches can't be skipped")
        pushed = set()
    in_flight = sorted(b["n"] for b in todo if b["n"] in pushed)
    if in_flight:
        print("in flight (pushed, not on main yet): %s" % ", ".join("batch-%02d" % n for n in in_flight))
        print("  if one of these stays here for more than an hour, its pull request needs a look")
    free = [b for b in todo if b["n"] not in pushed]
    if not lane:
        return free[0] if free else None
    own = [b for b in free if lane_of(b, catalog) == lane]
    if own:
        return own[0]
    other = [b for b in free if lane_of(b, catalog) != lane]
    if not other:
        return None
    # own lane finished: help the other lane from the far end so the two never meet on one batch
    print("%s lane is finished; helping the other lane from its far end" % lane)
    return other[-1] if lane == "horde" else other[0]


def main():
    plan = json.load(open(os.path.join(ROOT, "source", "batches.json"), encoding="utf-8"))
    catalog = json.load(open(os.path.join(ROOT, "source", "catalog.json"), encoding="utf-8"))
    done = translated_ids()
    args = sys.argv[1:]
    lane = None
    if "--lane" in args:
        i = args.index("--lane")
        lane = args[i + 1].lower() if i + 1 < len(args) else ""
        del args[i:i + 2]
        if lane not in ("alliance", "horde"):
            sys.exit("--lane must be alliance or horde")
    if args:
        batch = next(b for b in plan["batches"] if b["n"] == int(args[0]))
    else:
        batch = pick(plan, catalog, done, lane)
        if batch is None:
            print("ALL DONE: every planned batch is translated or in flight.")
            return
    lines = ["# Batch %d: %s  (%d quests, %d words)" % (batch["n"], batch["name"], len(batch["quests"]), batch["words"]),
             "# Output: batches/%s.json   keys per quest: t d o p c e (o1-o4 only if present) g" % batch["slug"], ""]
    for qid in batch["quests"]:
        q = catalog[str(qid)]
        lines.append("### %d  L%d  tier %d  %s%s" % (qid, q["level"], tier(q["level"]), q["zone"],
                                                     ("  giver: " + q["giver"]) if q.get("giver") else ""))
        for en_key, short in FIELD_ORDER:
            if q["en"].get(en_key):
                lines.append("[%s] %s" % (short, q["en"][en_key].replace("\n", "$b")))
        lines.append("")
    os.makedirs(os.path.join(ROOT, "work"), exist_ok=True)
    path = os.path.join(ROOT, "work", "batch_%02d.txt" % batch["n"])
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print("batch %d (%s, %s lane): %d quests, %d words -> %s" % (
        batch["n"], batch["name"], lane_of(batch, catalog), len(batch["quests"]), batch["words"],
        os.path.relpath(path, ROOT)))


if __name__ == "__main__":
    main()
