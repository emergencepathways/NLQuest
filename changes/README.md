# Changelog fragments

One file per batch: `changes/NN.md` holds that batch's CHANGELOG description, one line, without the
"Batch NN:" prefix and without the quest counts. Example (`changes/32.md`):

    Stranglethorn Vale from level 40 to 45 (Some Assembly Required, The Bloodsail Buccaneers chain, ...)

When the batch merges, `tools/sync_batch.py` (run by the *Batch auto-merge* workflow) turns it into
`- Batch 32: ... (25 quests, 855 in total).` under "Unreleased" in `CHANGELOG.md`.
Fragments exist so that two batches translated at the same time never edit `CHANGELOG.md` at once.
