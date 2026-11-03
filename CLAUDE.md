# Speurtocht.NL — instructions for Claude sessions

WoW addon (folder/TOC name `SpeurtochtNL`) that shows quest text in Dutch for language learners. Owner: Emergence Pathways (GitHub `emergencepathways/NLQuest`). The owner is learning Dutch (A1–A2 now) and plays WoW Forever / Classic Era on Linux.

## The standing task: translate the next batch

Two lanes run at the same time, each in its own chat:

- **"Next batch, alliance lane."** → `python3 tools/next_batch.py --lane alliance`
- **"Next batch, horde lane."** → `python3 tools/next_batch.py --lane horde`
- Plain **"next batch"** (no lane) → `python3 tools/next_batch.py` (first free batch).
- **"Do batch NN."** → `python3 tools/next_batch.py NN`.
- **"Also fix issue #12."** → fix it in the batch JSON it points to, mention "Fixes #12" under Corrected.

```bash
# one-time per session: Lua 5.1 for the offline tests
git clone -q --depth 1 --branch v5.1 https://github.com/lua/lua /tmp/lua51 && \
  (cd /tmp/lua51 && gcc -O2 -o /tmp/lua5.1 -DLUA_USE_POSIX lua.c $(ls *.c | grep -v -e '^lua.c$' -e '^luac.c$' -e '^print.c$') -lm)

git switch main && git pull
python3 tools/next_batch.py --lane <alliance|horde>   # English source -> work/batch_NN.txt (prints NN)
git switch -c batch-NN
# translate work/batch_NN.txt -> batches/NN-<slug>.json  (format: docs/WORKFLOW.md)
python3 tools/import_batch.py NN       # repeat: fix errors, add missing word meanings to "words", until READY
/tmp/lua5.1 tools/test_harness.lua     # must end with "0 failures"
# changes/NN.md: one line describing the batch for the CHANGELOG (format: changes/README.md).
#   Do NOT edit CHANGELOG.md - the auto-merge writes it, with the quest counts.
git add -A && git commit               # subject "Batch NN: <zones> (<n> quests)", body = Added / Changed / Corrected
git push -u origin batch-NN
```

After the push, GitHub's *Batch auto-merge* workflow (`tools/automerge.py`, a merge queue) opens the pull request (its description is the commit
body, so the Added / Changed / Corrected notes must be in the commit), syncs the branch with main, rebuilds
`SpeurtochtNL.toc`, `Data/Namen.lua` and `CHANGELOG.md`, runs the checks and merges. There is no need to
check that earlier batches are merged, and no manual merge step.

Tell the user the batch is pushed and will merge automatically, with the Added / Changed / Corrected notes.
The session may push branches and commits, but not tags or branch deletions.

`next_batch.py` lists batches that are "in flight" (pushed, not on main yet) and skips them, so two lanes
never pick the same batch. If it says a lane is finished, that lane helps the other one from its far end;
if it prints ALL DONE, tell the user.

### "Fix batch NN" (the auto-merge left a comment with the error on its pull request)

Read that comment first (`gh pr view batch-NN --comments` or the GitHub API); it holds the real error.

```bash
git fetch origin && git switch batch-NN && git merge origin/main
git checkout origin/main -- SpeurtochtNL.toc Data/Namen.lua CHANGELOG.md   # shared files: always take main's
python3 tools/import_batch.py NN       # fix what it reports in batches/NN-*.json until READY
/tmp/lua5.1 tools/test_harness.lua
git add -A && git commit -m "Batch NN: fix <what>" && git push    # the push retries the auto-merge
```

### Rules that keep the lanes safe

- A batch branch only adds its own files: `batches/NN-*.json`, `Data/Batch_NN_*.lua`, `changes/NN.md`
  (the `.toc` and `Data/Namen.lua` changes from the importer are fine; they get rebuilt at merge).
- Don't run `tools/plan_batches.py` while batches are in flight: it renumbers the unfinished plan.
- A word the other lane already defined may be reported missing in yours; just add its meaning again.

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
- `tools/`: pipeline, Anki sync, capture conversion, test harness, `automerge.py` + `sync_batch.py` (the merge queue). `docs/`: STYLE.md, WORKFLOW.md.
- `changes/NN.md`: per-batch CHANGELOG fragments. `.github/workflows/batch-automerge.yml`: the auto-merge.
- Player download: `.github/workflows/release.yml` runs `tools/package.py` after every merge and puts `SpeurtochtNL.zip` (one `SpeurtochtNL/` folder) on the `latest-build` release. No manual step.
- Releases: bump version in `Core.lua` and `SpeurtochtNL.toc`, move CHANGELOG "Unreleased" to a version heading.
