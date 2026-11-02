# Changelog

## Unreleased
- Batch 3: rest of Teldrassil (18 quests): Wellspring Lake, Oracle Glade, Ursal the Mauler, Mist, Denalan's timberling chain (96 quests in total).
- Plan covers all of Classic: Alliance 1-45 in the Forever leveling order, Alliance 46-60, then Horde (153 batches).
- CLAUDE.md: instructions so any new Claude session can run the next batch.
- **Melden** button in the reader and `/speur report`: builds a link to a pre-filled GitHub report. Missing quests include the English text (any faction, Horde too); translation fixes include the current Dutch.
- GitHub issue forms: *Missing quest* and *Translation fix*; link to Discussions for questions.
- Route follows the Forever dungeon leveling plan, with dungeon prequest chains (`+pre`) and Forever-only content marked for capture (`forever:`).

## 0.2.1 — 2026-11-02
- Batch 2: Shadowglen and Teldrassil up to Lake Al'Ameth and the Ban'ethil Barrow Den (29 quests, 78 in total).
- A word explained in any quest's word list now shows its meaning in every quest.
- Warcraft words added: furbolg, grell, grellkin, nightsaber, timberling, Gnarlpine.
- Translation pipeline: quest catalog with faction detection by quest giver, `route.txt` leveling order, batch planner (50 batches cover every Alliance quest up to level 45), batch importer with automatic checks.
- Git repository and release packaging (`.pkgmeta`).

## 0.2.0 — 2026-11-02
- Automatic Anki sync (`tools/anki_sync.py`, `tools/install_autosync.sh`) through AnkiConnect: deck and card type created for you, cards in both directions, updates instead of duplicates.
- Names, your character's name and Warcraft words can't be saved; clicking them turns them red with an explanation (`Data/Namen.lua`, `Data/Termen.lua`).
- A meaning for every Dutch word in the translated quests (`Data/Woordenboek_Batch1.lua`); `tools/build_lexicon.py` checks coverage.
- Word list opens next to the reader; larger settings window.
- On login, names saved by earlier versions are removed and empty meanings filled in.

## 0.1.1 — 2026-11-02
- Fix: clicking words in the reader now saves them.
- `/speur save woord [= betekenis]`, `/speur check`.

## 0.1.0 — 2026-11-02
- First version (as NederQuest, renamed Speurtocht.NL): Dutch quest text in the quest window and quest log, side-by-side reader, EN hover button, hold Alt for English, vocabulary saver, Anki text export, capture of untranslated quests.
- 49 quests: Coldridge Valley, Dun Morogh, dwarf class runes.
