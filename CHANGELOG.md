# Changelog

## Unreleased
- Batch 10: the Deadmines with its prequests (Red Silk Bandanas, Collecting Memories, Oh Brother..., Shoni's Underground Assault, The Defias Brotherhood finale with Edwin VanCleef, The Unsent Letter), the paladin Tome of Valor and Test of Righteousness chains (Duthorian Rall, Daphne and Jordan Stilwell), and the Wetlands up to level 25 (the Algaz Gauntlet, Rethiel the Greenwarden's gnoll quests, Menethil Harbor's crocolisk skins, Gobbler and the Menethil Statuette search, the Whelgar excavation, Sida's bag) (29 quests, 278 in total).
- Batch 9: Westfall up to level 20 (The Killing Fields, Thunderbrew, Red Leather Bandanas, the Westfall Lighthouse quests with Captain Grayson, Captain Sanders' Hidden Treasure, The People's Militia 3, the Defias Brotherhood chain up to the traitor escort) and the Wailing Caverns quests with their Ratchet prequests (Raptor Horns, Smart Drinks, Trouble at the Docks, Deviate Hides, Deviate Eradication, The Glowing Shard) (24 quests, 249 in total).
- Batch 8: Darkshore up to level 14 (Beached Sea Creature x2, How Big a Threat?, Buzzbox 323, Gubber Blump's fishing pole, Plagued Lands, Washed Ashore, the red crystal chain), The Hunter's Path (Ironforge) and Westfall up to level 14 (Furlbrow's Deed, Westfall Stew, the gryphon delivery to Osric Strang and back, The People's Militia 1–2, Goretusk Liver Pie, The Forgotten Heirloom, Patrolling Westfall, Poor Old Blanchy) (25 quests, 225 in total).
- Batch 7: the Consecrated Letter for paladins, Loch Modan up to level 14 (Brock's honor students and the gryphon flights, Rat Catching, blood sausages, the trogg quests, Stormpike's Order) and Darkshore up to level 14 (Buzzbox 827 and 411, Nessa's fish samples by hippogryph, Ameth'Aran, Asterion and the Bashal'Aran chain, Washed Ashore) (25 quests, 200 in total).
- Difficulty levels now follow quest level the same way for Alliance and Horde: A1–A2 up to level 20, A2–A2+ to 35, A2–B1 to 45, B1–B2 from 46, never above B2. The reader shows the new labels.
- Batch 6: the priest class quests up to level 10 for humans, dwarves and night elves: Hallowed Letter/Sigil, the first robes (heal and fortify Shaya, Roberts or Dolf), Stars of Elune and the Returning Home and Desperate Prayer messengers (22 quests, 175 in total).
- Batch 5: the last hunter pet quests (Strigid Screecher, Jocaste) and the warrior and rogue class quests up to level 10 for humans, dwarves, gnomes and night elves (28 quests, 153 in total).
- Batch 4: Darnassus (Temple of the Moon, Lady Sathrah, Grove of the Ancients) plus the night elf druid and hunter class quests up to level 10: Verdant/Etched Sigil, the Moonglade bear chain with Lunaclaw, and the Taming the Beast chains in Teldrassil and Dun Morogh (29 quests, 125 in total).
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
