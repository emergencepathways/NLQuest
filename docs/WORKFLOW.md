# Translation workflow

How every batch of quests gets from English to tested addon data. Written so that any work session, including a fresh Claude conversation with no memory of earlier ones, can pick up the next batch and produce the same quality.

## Why batches

All Alliance quests up to level 45 add up to about 1,300 quests and 177,000 English words. One batch is about **4,000 English words (20–35 quests)**. That's the most that can be translated carefully, with a word list per quest and a meaning for every new word, in one work session without running out of room. `route.txt` decides the order; `tools/plan_batches.py` cuts it into batches.

## One batch, step by step

```
python3 tools/next_batch.py --lane alliance   # 1. English source -> work/batch_NN.txt (or --lane horde)
git switch -c batch-NN                        #    one branch per batch
#                                               2. translate -> batches/NN-<slug>.json
python3 tools/import_batch.py NN              # 3. validate, build Data/Batch_NN_*.lua, update .toc
#                                               4. fix errors / add missing word meanings, re-run 3
lua5.1 tools/test_harness.lua                 # 5. offline test in a mock WoW client
#                                               6. changes/NN.md: the CHANGELOG line (see changes/README.md)
git add -A && git commit                      #    commit message: see below
git push -u origin batch-NN                   # 7. GitHub opens the pull request and merges it
```

### Two lanes in parallel

The plan has two parts that never share a quest: the Alliance route (batches with Alliance quests) and,
at the end, the Horde route (batches with only Horde and both-faction quests, 107 onward). Two chats can
work at the same time, one per lane:

| Lane | Picks | When its own batches run out |
|---|---|---|
| `--lane alliance` | the first free Alliance batch, front to back | takes the first free Horde batch |
| `--lane horde` | the first free Horde batch, front to back | takes the **last** free Alliance batch, back to front |

A batch is "free" when it isn't on main yet and has no `batch-NN` branch on GitHub. A pushed branch is
"in flight" and skipped, so the lanes never pick the same batch.

### The auto-merge

`.github/workflows/batch-automerge.yml` runs `tools/automerge.py`, a merge queue. It starts on every push to a
`batch-*` branch, every 30 minutes as a safety net, and by hand (*Actions → Batch auto-merge → Run workflow*).
Each run takes **every** `batch-NN` branch that isn't on main yet, lowest number first:

1. opens its pull request, with the commit message as title and notes;
2. merges main into the branch and takes main's copy of the three files every batch touches
   (`SpeurtochtNL.toc`, `Data/Namen.lua`, `CHANGELOG.md`), then rebuilds them for this batch with
   `tools/sync_batch.py NN` (re-import, names list, CHANGELOG line from `changes/NN.md` with the counts);
3. runs the test harness;
4. pushes the synced branch and merges it into main with a merge commit. GitHub marks the pull request
   as merged by itself, and comments with a link to the run.

If a batch fails, its pull request gets one comment with the actual error and the queue moves on to the
next batch. GitHub emails the owner the first time; the 30-minute retries of the same problem stay quiet.
Pushing a fix to the branch retries at once.
Every batch keeps its pull request page with the notes and the full diff, so nothing is lost by skipping
manual review: it can be read at any time under *Pull requests → Closed*.

Don't run `tools/plan_batches.py` while batches are in flight: it renumbers the unfinished part of the plan.

### Commit messages and pull requests

Every batch is a branch and a pull request, so GitHub keeps a page for it with the full diff and the notes. The auto-merge copies the commit message into the pull request, so the commit body carries the three headings:

```
Batch 3: Teldrassil (18 quests)

Added:     what's new (zones, quests, words, features)
Changed:   tools, code, or reworded existing translations
Corrected: mistakes fixed, with the issue number (Fixes #12)
```

Corrections reported while playing go in as GitHub issues (template: *Translation fix*), so every fix is traceable from report to change.

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
- **Difficulty by quest level, the same for both factions:** tier 1 (A1–A2) up to level 20, tier 2 (A2–A2+) to 35, tier 3 (A2–B1) to 45, tier 4 (B1–B2, literary) above. Never above B2.
- **Add nothing** that isn't in the English text.
- **Names stay English:** people, places, enemies, items.
- Keep the placeholders.
- Address the player as *je/jij*.

## Keeping AI use efficient

- **One batch per session.** Translate from `work/batch_NN.txt` only; don't open the big catalog or earlier batches.
- **Fresh conversations:** start a new chat every few batches. Everything needed lives in this repo (route, plan, style, previous batches), so long chat history adds cost without adding quality.
- **Let the tools check the details.** Placeholder, field and name checks are automatic, so a session's attention goes to good Dutch.
- **Each session ends with a commit.** A failed or interrupted session never loses finished work.
- **New quests in Forever:** the addon's capture feature records them in game; see the next section.

## WoW Forever: captured quests

Forever's new quests (IDs from about 90000) aren't in any database, and the game client doesn't ship quest
text: the server sends it when a quest is shown. So they get into the addon through play:

1. **In game:** with capture on (the default), every untranslated quest that's opened (quest giver dialog
   or quest log) is saved with its English text, zone, NPC, quest level and the player's faction, level,
   name, class and race. Opening a quest giver's dialog is enough; the quest doesn't need to be accepted.
   `/reload` or logging out writes it to `WTF/Account/<ACCOUNT>/SavedVariables/SpeurtochtNL.lua`.
2. **Into the plan** (on a fresh branch from main, while no `plan_batches.py` run is pending):

   ```
   git switch main && git pull && git switch -c forever-capture-YYYYMMDD
   python3 tools/import_capture.py <SpeurtochtNL.lua or captured.json> [more files...]
   git add source/ && git commit -m "Forever capture: <n> new quests" && git push -u origin HEAD
   ```

   It turns the player's name, class and race in the text back into `$n $c $r`, adds the quests to
   `source/catalog.json` (category `forever`) and appends new batches after the last one in
   `source/batches.json`, per faction and zone. Existing batch numbers never change, so this is safe
   while other batches are in flight. Merge that branch's pull request (it isn't a `batch-*` branch, so
   the auto-merge leaves it alone).
3. **Translate** as usual: "Next batch, alliance lane." picks up the new Alliance and both-faction batches,
   the horde lane the Horde ones.
4. **Changed text:** translated quests whose English changed in Forever are listed in
   `work/forever_changed.txt` with the old and new English and the file that holds the Dutch. Fix the
   Dutch in that batch JSON and re-import it on a `batch-NN` branch.

Things the capture can't recover: gender switches. The client shows *lad* or *lass*, not `$glad:lass;`,
so a captured word for the player's gender is translated neutrally or with a `$g` switch by hand.
Players who aren't the owner send their file as `captured.json` (`tools/capture_to_json.py`) on a
*Missing quest* issue; `import_capture.py` takes several files at once and merges them.

## Updating the source data

The English text comes from the VMaNGOS database (github.com/brotalnia/database), via `tools/build_catalog.py`. `source/catalog.json` is committed so sessions never need the 140 MB database. Rebuild it only to add new data, then run `tools/plan_batches.py`.
