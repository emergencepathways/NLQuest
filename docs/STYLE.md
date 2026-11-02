# SpeurtochtNL translation style guide

Every batch follows these rules so the Dutch reads as one consistent voice from level 1 to 60.

## Difficulty tiers (set per quest with `tier =`)

| Tier | Quest level | Target | How it reads |
|---|---|---|---|
| 1 | 1–20 | A1–A2 | Short sentences, one idea each. Everyday words. Present tense and perfectum; imperfectum only for very common verbs (was, had, kwam, zei, ging). Subordinate clauses only with *als, dat, omdat, want, dus*. |
| 2 | 21–35 | A2–A2+ | Sentences may combine two ideas. Common separable verbs (*terugbrengen, ophalen*), *om … te*, imperfectum freely, simple relative clauses with *die / dat*. Still everyday vocabulary, with a few less common words in the glossary. |
| 3 | 36–45 | A2–B1 | Longer sentences, relative clauses (*die / dat / waar*), passive voice, some idioms with glossary support. Broader vocabulary for feelings, opinions and abstract ideas. |
| 4 | 46–60 | B1–B2 | Keeps the literary, dramatic tone of endgame quests (lore, prophecy, villains). B1 at level 46 rising to B2 by 60. **B2 is the ceiling**: no C1 words or constructions, no archaic or very formal Dutch; when two words fit, choose the more common one. Rare words always go in the glossary. |

### Progression rules

- **Tier follows quest level only, for both factions.** An Alliance level-30 quest and a Horde level-30 quest get the same tier. Class quests, dungeon quests and Forever captures use their quest level like any other quest.
- **Grow gradually.** Within a tier, write the low end of the range at its lower level and the high end at its upper level (level 21 reads like late tier 1, level 35 like early tier 3), so the step between tiers is never a jump.
- **Never above B2.** If a sentence can only be said with C1 Dutch, simplify the wording, not the meaning.
- **Add nothing.** Translate what the English says: no extra facts, explanations, jokes, lore or flavour that the English doesn't have. Simplifying means splitting sentences and choosing easier words, never adding or dropping content. Obvious source errors (a stray developer name, a missing full stop) may be fixed and are listed under *Corrected* in the pull request.

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
