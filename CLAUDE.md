# Speurtocht.NL — instructions for Claude sessions

WoW addon (folder/TOC name `SpeurtochtNL`) that shows quest text in Dutch for language learners. Owner: Emergence Pathways (GitHub `emergencepathways/NLQuest`). The owner is learning Dutch (A1–A2 now) and plays WoW Forever / Classic Era on Linux.

## The standing task: translate the next batch

Unless the user asks for something else, "next batch" / "volgende batch" means:

```bash
# one-time per session: Lua 5.1 for the offline tests
git clone -q --depth 1 --branch v5.1 https://github.com/lua/lua /tmp/lua51 && \
  (cd /tmp/lua51 && gcc -O2 -o /tmp/lua5.1 -DLUA_USE_POSIX lua.c $(ls *.c | grep -v -e '^lua.c$' -e '^luac.c$' -e '^print.c$') -lm)

git switch main && git pull
python3 tools/next_batch.py            # English source -> work/batch_NN.txt (prints NN)
git switch -c batch-NN
# translate work/batch_NN.txt -> batches/NN-<slug>.json  (format: docs/WORKFLOW.md)
python3 tools/import_batch.py NN       # repeat: fix errors, add missing word meanings to "words", until READY
/tmp/lua5.1 tools/test_harness.lua     # must end with "0 failures"
# CHANGELOG.md: add a line under "Unreleased"
git add -A && git commit               # message: "Batch NN: <zones> (<n> quests)" + Added / Changed / Corrected
git push -u origin batch-NN
```

Then tell the user the batch is pushed, with the Added / Changed / Corrected notes for the pull request. The session may push branches and commits, but not tags or branch deletions.

One batch per turn (~4,000 English words). Read only `work/batch_NN.txt` for source text; don't open `source/catalog.json` or older batches (they're large and not needed).

## Translation rules (full version: docs/STYLE.md)

- **Tier by quest level, same for Alliance and Horde** (given in the batch file): 1 = A1–A2 (1–20), 2 = A2–A2+ (21–35), 3 = A2–B1 (36–45), 4 = B1–B2 literary (46–60). **Nothing above B2.** Difficulty grows gradually: low end of each tier at its first levels, high end at its last. Short, clear sentences at low tiers; keep the dramatic tone at tier 4 but choose the commoner word.
- **Add nothing that isn't in the English text**: no extra facts, explanations or flavour. Simplify by splitting sentences and choosing easier words, never by adding or dropping content.
- **Names stay English**: people, places, enemies, items, factions, dungeons. Objectives keep the exact English item/mob names (they must match the quest tracker): *Dood 6 Gnarlpine Ambushers.* / *Breng 8 Tough Wolf Meat naar Sten Stoutarm.*
- **Placeholders**: keep `$n $c $r $b`; turn `$glad:lass;` into `$gjongen:meid;`, `$ghis:her;` into `$gzijn:haar;`, etc.
- Address the player with *je/jij*. Natural Dutch, not word-for-word.
- `g` (word list): 5–15 harder words per quest, in the exact form used in the text.
- `words`: meanings for every word the importer lists as missing (base form in brackets).
- `terms`: only Warcraft words that are **not Dutch** (furbolg, timberling…). Real Dutch words (harpij, sater, dryade) go in `words`/`g`.

## Layout

- `Core.lua Text.lua Display.lua Reader.lua Vocab.lua Report.lua Capture.lua Options.lua`: the addon.
- `Data/`: translations. `Batch_NN_*.lua` are generated from `batches/NN-*.json` — edit the JSON, never the Lua.
- `route.txt` → `tools/plan_batches.py` → `source/batches.json` (the plan). `source/catalog.json` = English source (VMaNGOS).
- `tools/`: pipeline, Anki sync, capture conversion, test harness. `docs/`: STYLE.md, WORKFLOW.md.
- Releases: bump version in `Core.lua` and `SpeurtochtNL.toc`, move CHANGELOG "Unreleased" to a version heading.
