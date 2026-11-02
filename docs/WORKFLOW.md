# Translation workflow

How every batch of quests gets from English to tested addon data. Written so that any work session, including a fresh Claude conversation with no memory of earlier ones, can pick up the next batch and produce the same quality.

## Why batches

All Alliance quests up to level 45 add up to about 1,300 quests and 177,000 English words. One batch is about **4,000 English words (20–35 quests)**. That's the most that can be translated carefully, with a word list per quest and a meaning for every new word, in one work session without running out of room. `route.txt` decides the order; `tools/plan_batches.py` cuts it into batches.

## One batch, step by step

```
python3 tools/next_batch.py              # 1. English source -> work/batch_NN.txt
#                                          2. translate -> batches/NN-<slug>.json
python3 tools/import_batch.py NN         # 3. validate, build Data/Batch_NN_*.lua, update .toc
#                                          4. fix errors / add missing word meanings, re-run 3
lua5.1 tools/test_harness.lua            # 5. offline test in a mock WoW client
git add -A && git commit -m "Batch NN: <zones>"   # 6. commit (and push)
```

Releases bundle several batches: bump the version in `Core.lua` and `SpeurtochtNL.toc`, add a `CHANGELOG.md` entry, tag `vX.Y.Z`.

### Step 2: the batch file

`batches/NN-<slug>.json`:

```json
{
  "quests": {
    "458": {
      "t": "De beschermster van het woud",
      "d": "Gelukkig ben je er, $c. ...",
      "o": "Zoek de dryade Tarindrella.",
      "c": "Ik zie dat je me gevonden hebt, jonge $r. ...",
      "g": [["beschermster", "protector (f.)"], ["woud", "forest, woods"]]
    }
  },
  "words": { "gelukkig": "luckily, happy" },
  "terms": { "dryade": "dryad: a forest spirit from the Warcraft world" }
}
```

Keys per quest mirror the English fields in `work/batch_NN.txt`: `t` title, `d` description, `o` objectives, `p` progress text, `c` completion text, `e` end text, `o1`–`o4` custom objective lines. Give exactly the fields the English has.

- `g`: 5–15 words a learner at that tier might not know, using the exact form in the text.
- `words`: meanings for every Dutch word the importer reports as missing (base form in brackets).
- `terms`: Warcraft words that aren't Dutch, with a one-line explanation.

### Step 3: what the importer checks

**Errors** (block the batch):
- a quest or field missing, or a field the English doesn't have;
- `$n`, `$c`, `$r` or a `$gman:vrouw;` switch dropped, or a broken placeholder;
- text that still looks English.

**Warnings** (review them):
- an enemy, item or NPC name from the objectives that doesn't appear in the Dutch objectives;
- a word-list entry that isn't in the text.

After importing it rebuilds `Data/Namen.lua` and lists every Dutch word without a meaning. **A batch is done when the importer says READY.**

## Rules for the Dutch

Follow [STYLE.md](STYLE.md). In short:
- **Difficulty by quest level:** tier 1 (A1–A2) up to level 12, tier 2 (A2) to 25, tier 3 (A2–B1) to 42, tier 4 (B1, literary) above.
- **Names stay English:** people, places, enemies, items.
- Keep the placeholders.
- Address the player as *je/jij*.

## Keeping AI use efficient

- **One batch per session.** Translate from `work/batch_NN.txt` only; don't open the big catalog or earlier batches.
- **Fresh conversations:** start a new chat every few batches. Everything needed lives in this repo (route, plan, style, previous batches), so long chat history adds cost without adding quality.
- **Let the tools check the details.** Placeholder, field and name checks are automatic, so a session's attention goes to good Dutch.
- **Each session ends with a commit.** A failed or interrupted session never loses finished work.
- **New quests in Forever:** the addon's capture feature records them in game. `tools/capture_to_json.py` turns them into a batch input the same way.

## Updating the source data

The English text comes from the VMaNGOS database (github.com/brotalnia/database), via `tools/build_catalog.py`. `source/catalog.json` is committed so sessions never need the 140 MB database. Rebuild it only to add new data, then run `tools/plan_batches.py`.
