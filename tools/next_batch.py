#!/usr/bin/env python3
"""
Speurtocht.NL - print the English source text for a batch, compactly.

Usage (from the repo root):
    python3 tools/next_batch.py          the first unfinished batch
    python3 tools/next_batch.py 7        batch 7

Writes work/batch_NN.txt (not committed) and prints where it is plus a short
summary. The translator reads that file and writes batches/NN-<slug>.json
(format in docs/WORKFLOW.md), then runs tools/import_batch.py NN.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from plan_batches import translated_ids  # noqa: E402

FIELD_ORDER = [("Title", "t"), ("Details", "d"), ("Objectives", "o"), ("RequestItemsText", "p"),
               ("OfferRewardText", "c"), ("EndText", "e"),
               ("ObjectiveText1", "o1"), ("ObjectiveText2", "o2"), ("ObjectiveText3", "o3"), ("ObjectiveText4", "o4")]


def tier(level):
    return 1 if level <= 12 else 2 if level <= 25 else 3 if level <= 42 else 4


def main():
    plan = json.load(open(os.path.join(ROOT, "source", "batches.json"), encoding="utf-8"))
    catalog = json.load(open(os.path.join(ROOT, "source", "catalog.json"), encoding="utf-8"))
    done = translated_ids()
    if len(sys.argv) > 1:
        batch = next(b for b in plan["batches"] if b["n"] == int(sys.argv[1]))
    else:
        batch = next(b for b in plan["batches"] if not all(q in done for q in b["quests"]))
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
    print("batch %d (%s): %d quests, %d words -> %s" % (batch["n"], batch["name"], len(batch["quests"]),
                                                         batch["words"], os.path.relpath(path, ROOT)))


if __name__ == "__main__":
    main()
