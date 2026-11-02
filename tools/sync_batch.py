#!/usr/bin/env python3
"""
Speurtocht.NL - bring a batch branch up to date with main, right before it merges.

Usage (from the repo root, normally run by .github/workflows/batch-automerge.yml):
    python3 tools/sync_batch.py 32

Why: two lanes translate batches at the same time. Each batch branch only owns
its own files (batches/NN-*.json, Data/Batch_NN_*.lua, changes/NN.md). Three
files are shared by every batch and would collide between branches:
    SpeurtochtNL.toc, Data/Namen.lua, CHANGELOG.md
The workflow takes main's version of those three, then this script rebuilds
them for this batch:
  1. tools/import_batch.py NN  -> regenerates Data/Batch_NN, adds it to the .toc,
                                  rebuilds Data/Namen.lua; must say READY
  2. changes/NN.md             -> becomes the CHANGELOG line under "Unreleased",
                                  with the quest count and running total filled in
                                  (the fragment stays, so re-running is safe)
Exit code 0 = ready to merge, 1 = not ready.
"""
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from plan_batches import translated_ids  # noqa: E402


def changelog_line(n, batch):
    frag = os.path.join(ROOT, "changes", "%02d.md" % n)
    text = ""
    if os.path.exists(frag):
        text = " ".join(open(frag, encoding="utf-8").read().split()).strip()
    text = re.sub(r"^[-*]\s*", "", text)
    text = re.sub(r"^Batch\s+%d:\s*" % n, "", text, flags=re.I).rstrip(".")
    if not text:
        text = batch["name"]
    return "- Batch %d: %s (%d quests, %d in total)." % (n, text, len(batch["quests"]), len(translated_ids()))


def update_changelog(n, line):
    path = os.path.join(ROOT, "CHANGELOG.md")
    lines = open(path, encoding="utf-8").read().split("\n")
    lines = [l for l in lines if not l.startswith("- Batch %d:" % n)]   # re-runs replace, never duplicate
    try:
        head = lines.index("## Unreleased")
    except ValueError:
        head = 1
        lines[head:head] = ["", "## Unreleased"]
        head += 1
    lines.insert(head + 1, line)
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    n = int(sys.argv[1])
    plan = json.load(open(os.path.join(ROOT, "source", "batches.json"), encoding="utf-8"))
    batch = next((b for b in plan["batches"] if b["n"] == n), None)
    if batch is None:
        sys.exit("batch %d isn't in source/batches.json" % n)
    if not glob.glob(os.path.join(ROOT, "batches", "%02d-*.json" % n)):
        sys.exit("no batches/%02d-*.json on this branch" % n)
    imp = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "import_batch.py"), str(n)])
    if imp.returncode:
        sys.exit("NOT READY: import_batch.py %d failed after syncing with main" % n)
    line = changelog_line(n, batch)
    update_changelog(n, line)
    print("CHANGELOG: " + line[:140] + ("..." if len(line) > 140 else ""))
    print("SYNCED: batch %d is ready to merge." % n)


if __name__ == "__main__":
    main()
