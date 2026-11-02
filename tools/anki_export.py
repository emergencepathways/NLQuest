#!/usr/bin/env python3
"""
SpeurtochtNL - export saved words to an Anki import file.

Usage:
    python3 anki_export.py <path to SavedVariables/SpeurtochtNL.lua> [out.txt] [--new]

Where the SavedVariables file lives (Steam/Proton install):
    .../pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF/Account/<ACCOUNT>/SavedVariables/SpeurtochtNL.lua
    (use _forever_ or the Forever folder name once it exists)

The file is only written when you /reload or log out.

Import in Anki: File > Import > choose the .txt. Anki reads the header lines
(#separator, #columns, #tags column) automatically. Fields:
    Nederlands | English | Zin (sentence + quest) | Tags
Use a Basic note type (or "Basic (and reversed card)") and map the fields in order.
Re-importing is safe: Anki updates notes whose first field already exists.

--new   only words not exported before (tracked in nederquest_exported.json next to the output)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from savedvars import load  # noqa: E402


def clean(s):
    return str(s or "").replace("\t", " ").replace("\r", " ").replace("\n", "<br>")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_new = "--new" in sys.argv
    if not args:
        sys.exit(__doc__)
    sv = load(args[0])
    out = args[1] if len(args) > 1 else "nederquest_anki.txt"
    state_path = os.path.join(os.path.dirname(os.path.abspath(out)), "nederquest_exported.json")
    done = set(json.load(open(state_path))) if only_new and os.path.exists(state_path) else set()

    vocab = sv.get("SpeurtochtNLVocab") or {}
    entries = sorted(vocab.values(), key=lambda e: e.get("added", 0))
    lines = ["#separator:tab", "#html:true", "#columns:Nederlands\tEnglish\tZin\tTags", "#tags column:4"]
    written = []
    for e in entries:
        word = e.get("word", "")
        if word in done:
            continue
        back = clean(e.get("sentence"))
        if e.get("quest"):
            back += "<br><i>%s</i>" % clean(e["quest"])
        lines.append("\t".join([clean(word), clean(e.get("meaning")), back, "SpeurtochtNL WoW"]))
        written.append(word)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    if only_new:
        json.dump(sorted(done | set(written)), open(state_path, "w"), ensure_ascii=False, indent=0)
    print("wrote %d words to %s" % (len(written), out))


if __name__ == "__main__":
    main()
