# Speurtocht.NL — Dutch quest text for World of Warcraft

*Nederlandse versie: zie [LEESMIJ.md](LEESMIJ.md)*

Speurtocht.NL shows quest text in Dutch and leaves the rest of the game in English. It's built for learning Dutch while you play:

- **Graded Dutch** that starts at A1–A2 and grows to B1 as your character levels up.
- **The English original** whenever you need it: hold Alt, or hover the EN button.
- **A side-by-side reader** with Dutch next to English, where every Dutch word can be clicked.
- **A vocabulary list** of the words you click, ready to import into Anki.

**Version 0.2.0** · Classic Era (1.15) now · World of Warcraft: Forever (1.60) from launch

---

## 1. Install

1. Unzip the download. You get a folder called `SpeurtochtNL`.
2. Copy that folder into the game's AddOns folder. On Linux with Steam/Proton it is:
   ```
   ~/.local/share/Steam/steamapps/compatdata/<number>/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface/AddOns/
   ```
   For Forever, use the Forever game folder instead of `_classic_era_`. It appears after you install Forever and start it once.
3. Check the folder sits at `AddOns/SpeurtochtNL/SpeurtochtNL.toc`, not one level deeper.
4. On the character screen, open **AddOns** and make sure **Speurtocht.NL** is ticked. If it says "out of date", tick **Load out of date AddOns**. That happens when Blizzard updates the game before the addon is updated.
5. If an older version called **NederQuest** is in the AddOns folder, delete it. Otherwise both versions run at the same time.

WowUp only manages addons it downloaded itself, so it lists Speurtocht.NL as "unknown". That's normal.

---

## 2. Playing with it

Talk to a quest giver. The quest window shows Dutch, and the reader opens next to it: Dutch on the left, English on the right.

| You want to… | Do this |
|---|---|
| See the English for a moment | Hold **Alt** |
| See the English without changing the window | Hover the **EN** button on the quest window |
| Open or close the reader | Click **EN**, or type `/speur reader` |
| Hide the English column | Click **- EN** in the reader |
| Save a word | Click it in the reader. Saved words turn green. |
| Check a name or Warcraft word | Click it: it turns red and isn't saved |
| Remove a saved word | Right-click it |
| See your saved words | **Woorden** button in the reader, or `/speur vocab` |
| Open the settings | `/NLQuest` or `/speur` |

### Presets

The settings window has three quick choices. Every option can also be switched on or off on its own.

- **Alleen Nederlands**: Dutch only. No reader and no English help.
- **NL + Engels bij hover**: Dutch in the quest window, English through the EN button and Alt.
- **Naast elkaar**: Dutch in the quest window plus the side-by-side reader. This is the default.

### Difficulty grows with you

The reader shows each quest's level next to the title.

| Quest level | Dutch level | What it's like |
|---|---|---|
| 1–12 | A1–A2 | Short sentences, everyday words |
| 13–25 | A2 | Two ideas per sentence, common separable verbs |
| 26–42 | A2–B1 | Longer sentences, relative clauses, some idioms |
| 43–60 | B1 | Keeps the dramatic tone of endgame stories, with harder words explained |

Names of people, places, enemies and items stay English. That way they match the map, the tooltips and the quest tracker.

Under each translation, the reader lists **Woorden in deze quest**: the harder words from that quest with their meaning. Click one to save it.

---

## 3. Saved words → Anki

Each saved word keeps four things: the Dutch word, its English meaning, the sentence you found it in, and the quest title. Every word in the translated quests has a meaning, so the English side of your cards is never empty.

Names and Warcraft words are never saved. Clicking **Durnan**, **Anvilmar**, **troggs** or your own character's name turns the word **red** and tells you why instead of adding it to your list. Hovering shows the same explanation.

### Automatic: words go to Anki by themselves (recommended)

WoW addons can't write files on your computer, but WoW itself saves the addon's data to disk when you log out or `/reload`. A small sync program on your computer watches for that save and sends new words straight into Anki.

**One-time setup** (about five minutes):

1. **Install AnkiConnect in Anki.** In Anki: **Tools › Add-ons › Get Add-ons…**, enter the code `2055492159`, click OK, and restart Anki.
2. **Run the sync once.** Open a terminal in the addon's `tools` folder and run:
   ```
   python3 anki_sync.py
   ```
   It finds your WoW folder by itself and creates a deck and a card type called **Speurtocht.NL** in Anki. Each word gets two cards: Dutch → English and English → Dutch, with the example sentence and quest title on the back. (Use `--one-way` the first time if you only want Dutch → English.)
3. **Make it automatic.** In the same folder, run:
   ```
   bash install_autosync.sh
   ```
   From now on the sync starts with your desktop and runs quietly in the background.

**From then on:** keep Anki open while you play. When you've saved some words, click **Naar Anki** in the word list (it does a quick `/reload`), or just log out. A few seconds later the cards are in your **Speurtocht.NL** deck. If Anki was closed, the words are sent the next time you open it.

If a word later gets a better meaning, its card is updated rather than duplicated.

To stop the background sync: `bash install_autosync.sh --remove`.

### Manual alternative: copy and paste

If you'd rather not install anything:

1. In Anki, make a note type with three fields once: **Tools › Manage Note Types › Add › Basic (and reversed card)**, name it `Speurtocht.NL`, and rename its fields to `Nederlands`, `English` and `Zin`.
2. In game: `/speur vocab` › **Kopieer tekst** (only words you haven't copied before). The text is already selected: press **Ctrl+C**, then click **Markeer als geëxporteerd**.
3. Paste into a text editor, save as `speurtocht.txt`, then in Anki: **File › Import**. Choose note type `Speurtocht.NL`, map columns 1–4 to Nederlands, English, Zin and Tags, and set **Existing notes** to *Update*.

---

## 4. Quests that aren't translated yet

When you open a quest that has no translation, Speurtocht.NL leaves the English as it is and quietly saves a copy of the text. `/speur capture` shows how many it has saved.

To get them translated, log out (or `/reload`) and run:

```
python3 tools/capture_to_json.py "<game folder>/WTF/Account/<ACCOUNT>/SavedVariables/SpeurtochtNL.lua" captured.json
```

Send `captured.json` and those quests go into the next batch. This is also how Forever's new quests get translated, including the Cozy Sleeping Bag chain: play through them once, then send the file.

If Forever changes the English text of a quest that's already translated, the reader marks it *tekst gewijzigd* and the new text is saved separately, so the translation can be updated.

---

## 5. What's translated

| Batch | Quests | Status |
|---|---|---|
| Coldridge Valley | 13 | ✅ |
| Dun Morogh | 31 | ✅ |
| Dwarf class runes (level 1) | 5 | ✅ |
| Northshire + Elwynn Forest | 48 | next |
| Shadowglen + Teldrassil | 48 | |
| Alliance class quests up to level 10 | 102 | |
| Dungeons, levels 10–60 (Alliance) | 214 | |
| Attunements (Molten Core, Onyxia, Blackwing Lair, Upper Blackrock Spire, Scholomance, Blackrock Depths key) | 31 | |
| Cozy Sleeping Bag (Forever) | — | after launch, via capture |

`tools/roadmap_v1.json` lists every quest ID in each batch.

---

## 6. Chat commands

| Command | What it does |
|---|---|
| `/NLQuest` or `/speur` | Open the settings |
| `/speur reader` | Open or close the reader |
| `/speur vocab` | Open your saved words |
| `/speur save woord` | Save a word by typing it (uses the meaning if the addon knows it) |
| `/speur save woord = meaning` | Save a word with your own meaning |
| `/speur check` | Check whether the reader's words are clickable |
| `/speur export` | Copy-and-paste export window (all words) |
| `/speur capture` | How many untranslated quests have been saved |
| `/speur status` | Version, game build, and whether the current quest is translated |
| `/speur help` | List the commands |

Commands are not case-sensitive.

---

## 7. Troubleshooting

- **Nothing is in Dutch:** type `/speur status`. It shows the quest ID and whether it's translated. Also check that **Speurtocht.NL aan** is ticked in the settings.
- **A Lua error pops up:** type `/console scriptErrors 1`, do the same thing again, and send a screenshot of the whole error.
- **Clicking words doesn't save them:** update to 0.1.1 or later. Click words in the **reader panel**, not in the quest window itself (the quest window's text can't be clicked). Type `/speur check` and send the line it prints. You can always save a word by typing `/speur save woord`.
- **The reader is off-screen:** open the settings and click **Lezer terugzetten**.
- **Words don't arrive in Anki:** check that Anki is open and AnkiConnect is installed, then run `python3 anki_sync.py` in the `tools` folder to see what it says. Background service log: `journalctl --user -u speurtocht-anki`.

---

## 8. For developers

| Path | What it is |
|---|---|
| `Core.lua` | Namespace, settings, data registry, lookup by quest ID (fallback: English title) |
| `Text.lua` | `$n/$c/$r/$b/$g` expansion, Dutch class and race names, clickable-word markup |
| `Display.lua` | Quest dialog and quest log text replacement, EN button, Alt to peek |
| `Reader.lua` | Side-by-side reader |
| `Vocab.lua` | Word saver, word list window, Anki export |
| `Capture.lua` | Saves untranslated and changed quests |
| `Options.lua` | Settings window and chat commands |
| `Data/*.lua` | Translations, one file per batch |
| `docs/STYLE.md` | Translation rules every batch follows |
| `tools/extract_vanilla_quests.py` | English source text from the VMaNGOS database |
| `tools/build_manifest.py` | Sorts quests into batches (finds dungeon quests by where their objectives spawn) |
| `tools/anki_sync.py`, `tools/install_autosync.sh` | Sends saved words to Anki via AnkiConnect, optionally as a background service |
| `tools/build_lexicon.py` | Builds `Data/Namen.lua` and checks every Dutch word has a meaning |
| `Data/Termen.lua` | Warcraft fantasy terms with explanations |
| `tools/test_harness.lua` | Offline test in a mock WoW environment: `lua5.1 tools/test_harness.lua` |

English source text: VMaNGOS world database (github.com/brotalnia/database). Speurtocht.NL is an independent fan project, not affiliated with Blizzard Entertainment.
