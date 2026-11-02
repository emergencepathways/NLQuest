#!/usr/bin/env python3
"""
Speurtocht.NL - validate a translated batch and turn it into addon data.

Usage (from the repo root):
    python3 tools/import_batch.py 2

Reads batches/02-*.json, checks it against the English source, writes
Data/Batch_02_<slug>.lua, adds it to the .toc, rebuilds the names list and
reports any Dutch word that still has no meaning. Safe to run repeatedly.

Batch file format (JSON):
{
  "quests": { "<id>": { "t": "...", "d": "...", "o": "...", "p": "...", "c": "...",
                        "g": [["woord", "meaning"], ...] } },
  "words":  { "woord": "meaning (base form)" },      # dictionary additions
  "terms":  { "warcraftword": "explanation" }        # fantasy terms (shown red)
}

Exit code 0 = ready to commit, 1 = errors to fix. Warnings don't block.
"""
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from next_batch import FIELD_ORDER, tier  # noqa: E402

ENGLISH_ONLY = {"the", "and", "you", "your", "with", "have", "that", "this", "will", "would", "from",
                "they", "what", "there", "please", "my", "our", "for", "are", "was", "it's", "i'm", "don't"}
WORD = re.compile(r"[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'\-]*")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "$b") + '"'


def count(pat, s):
    return len(re.findall(pat, s or ""))


def check_quest(qid, en, nl, errors, warnings):
    tag = "quest %s" % qid
    for en_key, short in FIELD_ORDER:
        has_en, has_nl = bool(en.get(en_key)), bool(nl.get(short))
        if has_en and not has_nl:
            errors.append("%s: missing '%s' (English %s)" % (tag, short, en_key))
        elif has_nl and not has_en:
            errors.append("%s: '%s' given but English has no %s" % (tag, short, en_key))
    for short, text in nl.items():
        if short == "g" or not isinstance(text, str):
            continue
        en_text = en.get(dict((s, e) for e, s in FIELD_ORDER).get(short, ""), "")
        for ph, label in ((r"\$[nN]", "$n"), (r"\$[cC]", "$c"), (r"\$[rR]", "$r")):
            if count(ph, en_text) and not count(ph, text):
                errors.append("%s.%s: English uses %s, Dutch doesn't" % (tag, short, label))
        if count(r"\$[gG]", en_text) and not re.search(r"\$[gG][^:;]+:[^;]+;", text):
            errors.append("%s.%s: English has a $g male:female; switch, Dutch doesn't" % (tag, short))
        bad = re.findall(r"\$[^nNcCrRbBgG]", text)
        if bad:
            errors.append("%s.%s: unknown placeholder %s" % (tag, short, bad[0]))
        if re.search(r"\$[gG](?![^;]*;)", text):
            errors.append("%s.%s: $g switch not closed with ';'" % (tag, short))
        words = [w.lower() for w in WORD.findall(re.sub(r"\$[gG][^;]*;", "", text))]
        if words:
            eng = [w for w in words if w in ENGLISH_ONLY]
            if len(eng) > max(2, len(words) * 0.04):
                errors.append("%s.%s: looks untranslated (%s)" % (tag, short, ", ".join(sorted(set(eng))[:6])))
    # names in the objectives should survive translation (they match the tracker)
    if en.get("Objectives") and nl.get("o"):
        for name in re.findall(r"(?:[A-Z][\w'’-]+)(?:\s+(?:of|the|[A-Z][\w'’-]+))*\s+[A-Z][\w'’-]+", en["Objectives"]):
            if name not in nl["o"]:
                warnings.append("%s: objective name '%s' not found in Dutch objectives" % (tag, name))
    gl = nl.get("g") or []
    if not gl:
        warnings.append("%s: no word list (g)" % tag)
    alltext = " ".join(v for k, v in nl.items() if k != "g").lower()
    for pair in gl:
        if not (isinstance(pair, list) and len(pair) == 2):
            errors.append("%s: bad word-list entry %r" % (tag, pair))
        elif pair[0].lower().split(" ")[0] not in alltext:
            warnings.append("%s: word-list entry '%s' isn't in the text" % (tag, pair[0]))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    n = int(sys.argv[1])
    plan = json.load(open(os.path.join(ROOT, "source", "batches.json"), encoding="utf-8"))
    catalog = json.load(open(os.path.join(ROOT, "source", "catalog.json"), encoding="utf-8"))
    batch = next(b for b in plan["batches"] if b["n"] == n)
    files = glob.glob(os.path.join(ROOT, "batches", "%02d-*.json" % n))
    if not files:
        sys.exit("no batches/%02d-*.json yet" % n)
    data = json.load(open(files[0], encoding="utf-8"))
    quests = data.get("quests", {})

    errors, warnings = [], []
    for qid in batch["quests"]:
        if str(qid) not in quests:
            errors.append("quest %d (%s) missing from the batch file" % (qid, catalog[str(qid)]["en"]["Title"]))
    for qid, nl in quests.items():
        if qid not in catalog:
            errors.append("quest %s isn't in the catalog" % qid)
            continue
        check_quest(qid, catalog[qid]["en"], nl, errors, warnings)

    lua_name = "Batch_%02d_%s.lua" % (n, re.sub(r"[^A-Za-z0-9]+", "_", batch["slug"].split("-", 1)[1]).strip("_").title())
    out = ["-- Speurtocht.NL batch %d: %s" % (n, batch["name"]),
           "-- Generated from batches/%s by tools/import_batch.py - edit the JSON, not this file." % os.path.basename(files[0]),
           "local _, NQ = ...", "", "NQ:AddQuests({", ""]
    for qid in sorted(quests, key=lambda i: (catalog.get(i, {}).get("level", 0), int(i))):
        if qid not in catalog:
            continue
        c, nl = catalog[qid], quests[qid]
        out.append("[%s] = { en = %s, tier = %d," % (qid, lua_str(c["en"]["Title"]), tier(c["level"])))
        for _, short in FIELD_ORDER:
            if nl.get(short):
                out.append("  %s = %s," % (short, lua_str(nl[short])))
        if nl.get("g"):
            out.append("  g = { " + ", ".join("{%s, %s}" % (lua_str(a), lua_str(b)) for a, b in nl["g"]) + " },")
        out.append("},")
        out.append("")
    out.append("})")
    if data.get("words"):
        out += ["", "NQ:AddWords({"] + ["    [%s] = %s," % (lua_str(k.lower()), lua_str(v))
                                         for k, v in sorted(data["words"].items())] + ["})"]
    if data.get("terms"):
        out += ["", "NQ:AddTerms({"] + ["    [%s] = %s," % (lua_str(k.lower()), lua_str(v))
                                         for k, v in sorted(data["terms"].items())] + ["})"]
    path = os.path.join(ROOT, "Data", lua_name)
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")

    toc_path = os.path.join(ROOT, "SpeurtochtNL.toc")
    toc = open(toc_path, encoding="utf-8").read()
    entry = "Data\\" + lua_name
    if entry not in toc:
        lines = toc.split("\n")
        last_data = max(i for i, l in enumerate(lines) if l.startswith("Data\\"))
        lines.insert(last_data + 1, entry)
        open(toc_path, "w", encoding="utf-8").write("\n".join(lines))

    print("batch %d: %d quests -> Data/%s" % (n, len(quests), lua_name))
    for w in warnings:
        print("  warning: " + w)
    for e in errors:
        print("  ERROR: " + e)
    lex = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_lexicon.py"),
                          os.path.join(ROOT, "source", "catalog.json")], capture_output=True, text=True)
    print(lex.stdout.strip())
    if lex.returncode:
        print(lex.stderr)
    missing = "without a meaning" in lex.stdout
    if errors or missing:
        print("NOT READY: fix the errors%s above and run again." % (" and add the missing words" if missing else ""))
        sys.exit(1)
    print("READY: run the tests, then commit.")


if __name__ == "__main__":
    main()
