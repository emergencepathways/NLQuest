#!/usr/bin/env python3
"""
SpeurtochtNL - turn quests recorded in-game into a translation batch.

Usage:
    python3 capture_to_json.py <SavedVariables/SpeurtochtNL.lua> [captured.json]

The addon records the English text of every quest you open that has no Dutch
translation yet (SpeurtochtNLCapture.quests), and translated quests whose
English title changed (SpeurtochtNLCapture.changed). This is how WoW Forever's
new quests (e.g. the Cozy Sleeping Bag chain) get into the addon.

Send the resulting JSON back for translation; the output keeps the same field
names the addon's data files use.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from savedvars import load  # noqa: E402

FIELD_MAP = {"title": "Title", "desc": "Details", "obj": "Objectives",
             "progress": "RequestItemsText", "reward": "OfferRewardText"}


def convert(store):
    out = {}
    for qid, e in sorted(store.items(), key=lambda kv: str(kv[0])):
        out[str(qid)] = {
            "en": {FIELD_MAP[k]: v for k, v in e.items() if k in FIELD_MAP and v},
            "zone": e.get("zone"), "npc": e.get("npc"),
            "build": e.get("build"), "toc": e.get("toc"),
        }
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sv = load(sys.argv[1])
    cap = sv.get("SpeurtochtNLCapture") or {}
    result = {"new": convert(cap.get("quests") or {}), "changed": convert(cap.get("changed") or {})}
    out = sys.argv[2] if len(sys.argv) > 2 else "nederquest_captured.json"
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=1)
    print("%d new, %d changed -> %s" % (len(result["new"]), len(result["changed"]), out))


if __name__ == "__main__":
    main()
