#!/usr/bin/env python3
"""
Speurtocht.NL - send your saved words straight into Anki. No copy and paste.

How it works
    WoW writes your word list to disk when you log out or /reload (the
    "Naar Anki" button in the word list does a /reload for you). This script
    reads that file and adds new words to Anki through the AnkiConnect add-on.

One-time setup
    1. In Anki: Tools > Add-ons > Get Add-ons... > code 2055492159 (AnkiConnect),
       then restart Anki.
    2. Run once:   python3 anki_sync.py
       It finds your WoW folder, creates the deck "Speurtocht.NL" and the note
       type "Speurtocht.NL" (Nederlands / English / Zin, cards both directions).
    3. Optional, recommended: run tools/install_autosync.sh once. From then on
       the sync runs in the background whenever you're logged in to your desktop.

Usage
    python3 anki_sync.py                 sync once
    python3 anki_sync.py --watch         keep running; sync every time WoW saves
    python3 anki_sync.py --path FILE     use this SavedVariables file
    python3 anki_sync.py --deck NAME     deck name (default: Speurtocht.NL)
    python3 anki_sync.py --one-way       only Dutch -> English cards

Anki must be open for words to arrive. Words saved while Anki is closed are
sent the next time it is open (in --watch mode, automatically).
"""
import argparse
import glob
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from savedvars import load  # noqa: E402

ANKI_URL = "http://127.0.0.1:8765"
MODEL = "Speurtocht.NL"
FIELDS = ["Nederlands", "English", "Zin"]
TAGS = ["SpeurtochtNL", "WoW"]
STATE_DIR = os.path.join(os.path.expanduser("~"), ".local", "share", "speurtocht-nl")
STATE_FILE = os.path.join(STATE_DIR, "synced.json")

CSS = """.card { font-family: "Noto Sans", Arial, sans-serif; font-size: 26px; text-align: center;
  color: #2b2118; background: #f6efe2; }
.nl { font-size: 34px; font-weight: 600; color: #7a3e12; }
.en { font-size: 26px; }
.zin { margin-top: 22px; font-size: 17px; color: #5b4a3a; line-height: 1.45; }
.zin i { color: #8a7560; }
.nightMode .card, .card.nightMode { color: #eadfcd; background: #2a241e; }
.nightMode .nl { color: #f0b37e; }
.nightMode .zin { color: #c9b9a4; }"""

TEMPLATES = [
    {"Name": "NL → EN",
     "Front": '<div class="nl">{{Nederlands}}</div>',
     "Back": '{{FrontSide}}<hr id="answer"><div class="en">{{English}}</div><div class="zin">{{Zin}}</div>'},
    {"Name": "EN → NL",
     "Front": '{{#English}}<div class="en">{{English}}</div>{{/English}}',
     "Back": '{{FrontSide}}<hr id="answer"><div class="nl">{{Nederlands}}</div><div class="zin">{{Zin}}</div>'},
]

# Where Steam/Proton, Flatpak Steam and Lutris keep WoW on Linux
SEARCH = [
    "~/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "~/.steam/steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "~/Games/*/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "~/.wine/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "/mnt/*/SteamLibrary/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
    "/media/*/*/SteamLibrary/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/*/WTF/Account/*/SavedVariables/SpeurtochtNL.lua",
]


class AnkiUnavailable(Exception):
    pass


def anki(action, **params):
    body = json.dumps({"action": action, "version": 6, "params": params}).encode("utf-8")
    req = urllib.request.Request(ANKI_URL, body, {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            reply = json.load(resp)
    except (urllib.error.URLError, ConnectionError, TimeoutError) as exc:
        raise AnkiUnavailable(str(exc))
    if reply.get("error"):
        raise RuntimeError("AnkiConnect %s: %s" % (action, reply["error"]))
    return reply.get("result")


def find_files(explicit=None):
    if explicit:
        return [explicit]
    found = []
    for pattern in SEARCH:
        found.extend(glob.glob(os.path.expanduser(pattern)))
    # skip SavedVariables.bak copies; keep one entry per real file
    return sorted({os.path.realpath(p) for p in found if p.endswith(".lua")})


def read_words(paths):
    """Merge the word lists of every WoW install / account found."""
    words = {}
    for path in paths:
        try:
            sv = load(path)
        except Exception as exc:  # half-written file while WoW is saving
            print("  could not read %s yet (%s)" % (path, exc))
            continue
        for key, e in (sv.get("SpeurtochtNLVocab") or {}).items():
            word = e.get("word") or key
            old = words.get(word)
            if not old or (not old.get("meaning") and e.get("meaning")):
                words[word] = e
    return words


def card_fields(e):
    zin = (e.get("sentence") or "").replace("\n", "<br>")
    if e.get("quest"):
        zin += "<br><i>%s</i>" % e["quest"] if zin else "<i>%s</i>" % e["quest"]
    return {"Nederlands": e.get("word", ""), "English": e.get("meaning") or "", "Zin": zin}


def ensure_setup(deck, one_way):
    if MODEL not in anki("modelNames"):
        anki("createModel", modelName=MODEL, inOrderFields=FIELDS, css=CSS,
             isCloze=False, cardTemplates=TEMPLATES[:1] if one_way else TEMPLATES)
        print("  created note type '%s'" % MODEL)
    else:
        have = anki("modelFieldNames", modelName=MODEL)
        missing = [f for f in FIELDS if f not in have]
        if missing:
            sys.exit("The note type '%s' exists but has no field(s) %s. Rename its fields to "
                     "Nederlands / English / Zin in Tools > Manage Note Types > Fields." % (MODEL, ", ".join(missing)))
    if deck not in anki("deckNames"):
        anki("createDeck", deck=deck)
        print("  created deck '%s'" % deck)


def load_state():
    try:
        return json.load(open(STATE_FILE, encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    json.dump(state, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    os.replace(tmp, STATE_FILE)


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def sync(paths, deck, one_way):
    words = read_words(paths)
    state = load_state()
    todo = {w: e for w, e in words.items() if state.get(w) != (e.get("meaning") or "")}
    if not todo:
        return 0, 0
    ensure_setup(deck, one_way)
    added = updated = 0
    for word, e in sorted(todo.items(), key=lambda kv: kv[1].get("added", 0)):
        fields = card_fields(e)
        ids = anki("findNotes", query='"note:%s" "Nederlands:%s"' % (MODEL, esc(word)))
        if ids:
            info = anki("notesInfo", notes=ids[:1])[0]
            current = info["fields"]
            changes = {}
            if not current["English"]["value"] and fields["English"]:
                changes["English"] = fields["English"]
            if not current["Zin"]["value"] and fields["Zin"]:
                changes["Zin"] = fields["Zin"]
            if changes:
                anki("updateNoteFields", note={"id": ids[0], "fields": changes})
                updated += 1
        else:
            anki("addNote", note={"deckName": deck, "modelName": MODEL, "fields": fields, "tags": TAGS,
                                  "options": {"allowDuplicate": False, "duplicateScope": "deck"}})
            added += 1
        state[word] = e.get("meaning") or ""
    save_state(state)
    return added, updated


def report(added, updated):
    if added or updated:
        print("%s  %d new card(s) in Anki%s" % (time.strftime("%H:%M:%S"), added,
                                                  ", %d updated" % updated if updated else ""))


def main():
    ap = argparse.ArgumentParser(description="Send Speurtocht.NL words to Anki.")
    ap.add_argument("--watch", action="store_true", help="keep running and sync whenever WoW saves")
    ap.add_argument("--path", help="SavedVariables/SpeurtochtNL.lua to read")
    ap.add_argument("--deck", default="Speurtocht.NL")
    ap.add_argument("--one-way", action="store_true", help="only Dutch -> English cards (new note type only)")
    args = ap.parse_args()

    paths = find_files(args.path)
    if not args.watch:
        if not paths:
            sys.exit("No SpeurtochtNL.lua found yet. Save a word in game, then /reload or log out, and try again.\n"
                     "Or point to it: --path \".../WTF/Account/<ACCOUNT>/SavedVariables/SpeurtochtNL.lua\"")
        for p in paths:
            print("reading %s" % p)
        try:
            added, updated = sync(paths, args.deck, args.one_way)
        except AnkiUnavailable:
            sys.exit("Anki isn't reachable. Open Anki (with the AnkiConnect add-on installed) and run this again.")
        print("done: %d new card(s), %d updated" % (added, updated) if (added or updated) else "nothing new to add")
        return

    print("Speurtocht.NL Anki sync: watching for WoW saves (Ctrl+C to stop)")
    seen, pending, warned = {}, True, False
    last_search = 0
    while True:
        if time.time() - last_search > 60 or not paths:
            paths = find_files(args.path)
            last_search = time.time()
        for p in paths:
            try:
                m = os.path.getmtime(p)
            except OSError:
                continue
            if seen.get(p) != m:
                seen[p] = m
                pending = True
        if pending and paths:
            time.sleep(1.5)  # let WoW finish writing
            try:
                report(*sync(paths, args.deck, args.one_way))
                pending, warned = False, False
            except AnkiUnavailable:
                if not warned:
                    print("Anki isn't open; new words will be sent as soon as it is.")
                    warned = True
            except Exception as exc:  # keep the background service alive
                print("sync error: %s" % exc)
                pending = False
        time.sleep(3 if not pending else 15)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
