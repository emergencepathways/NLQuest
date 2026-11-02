# SpeurtochtNL translation style guide

Every batch follows these rules so the Dutch reads as one consistent voice from level 1 to 60.

## Difficulty tiers (set per quest with `tier =`)

| Tier | Quest level | Target | How it reads |
|---|---|---|---|
| 1 | 1–12 | A1–A2 | Short sentences, one idea each. Present tense and perfectum; imperfectum only for very common verbs (was, had, kwam, zei). Everyday words. Subordinate clauses only with *als, dat, omdat, want, dus*. |
| 2 | 13–25 | A2 | Sentences may combine two ideas. Common separable verbs (*terugbrengen, ophalen*) and *om … te* constructions. Imperfectum freely. |
| 3 | 26–42 | A2–B1 | Longer sentences, relative clauses (*die / dat / waar*), passive voice, some idioms with glossary support. |
| 4 | 43–60 | B1 | Keeps the literary, dramatic tone of endgame quests (lore, prophecy, villains), but chooses the more common word whenever two words fit. Rare words always go in the glossary. |

## Fixed conventions

- **Names stay English**: people, places, enemies, items, factions (Coldridge Valley, Grik'nir the Cold, Tough Wolf Meat, Ironforge). They must match the map, tooltips and the quest tracker, which stay English.
- **Common nouns are Dutch** even for creatures: *troggs, trollen, wolven, beren, zwijnen, gnomen, dwergen*.
- **Objectives** use imperative + English names: *Dood 6 Rockjaw Troggs.* / *Breng 8 Tough Wolf Meat naar Sten Stoutarm.*
- **Address**: *je/jij* everywhere (NPCs never use *u* except formal nobles or royalty in tier 4).
- **Placeholders** keep the game's syntax: `$n` name, `$c` class, `$r` race, `$b` line break, `$gmannelijk:vrouwelijk;` (e.g. `$gjongen:meid;`). Class and race expand to lowercase Dutch (*krijger/krijgster, dwerg*).
- **Exclamations** get natural Dutch equivalents, not literal ones: *By Magni's beard* → *Bij Magni's baard*; *Light-blasted* → *vervloekte*; *Huzzah* → *Hoera*.
- **Accent/dialect**: NPC voice comes through word choice and rhythm, never misspelling — learners must be able to look every word up.

## Glossary (`g =`)

- 5–15 entries per quest; words a learner at that tier is unlikely to know.
- The Dutch side uses the **exact form in the text** (so clicking the word in the reader finds it), with the base form in brackets in the English side when it helps: `{"durfde", "dared (durven)"}`.
- Multi-word expressions are fine: `{"zo taai als een spijker", "tough as nails"}`.
