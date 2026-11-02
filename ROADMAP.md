# Speurtocht.NL roadmap

Goal: every quest for every Alliance character in Dutch, then a public release, then the Horde.
Each **batch** is about 4,000 English words (20–35 quests) and is one work session. See [docs/WORKFLOW.md](docs/WORKFLOW.md).

Batch numbers below come from `source/batches.json`. Run `python3 tools/plan_batches.py` to see the current plan. Reordering `route.txt` reorders the batches.

## Scope

| Part | Quests | English words | Batches |
|---|---|---|---|
| Alliance, levels 1–45 | 1,321 | 177,000 | 50 (1 done) |
| Alliance, levels 46–60 (incl. dungeons, raids, attunements) | 1,648 | 207,000 | ~52 |
| Horde-only quests | 1,286 | 182,000 | ~46 |
| WoW Forever's new quests | unknown until launch | | via in-game capture |

## Phase 0 — Foundation ✅ (0.1.0–0.2.0)
- The addon: Dutch quest text, side-by-side reader, word saver, red names and Warcraft words, automatic Anki sync.
- Batch 1: Coldridge Valley, Dun Morogh, dwarf class runes (49 quests).

## Phase 1 — Night Elf start and class quests to level 10 → release 0.3
| Batch | Content |
|---|---|
| 2–3 | Shadowglen, Teldrassil |
| 4 | Darnassus, druid and hunter quests ≤ 10 |
| 5–7 | Warrior, rogue, priest, paladin quests ≤ 10 |

## Phase 2 — Levels 10–20 → release 0.4
| Batch | Content |
|---|---|
| 7–8 | Loch Modan, Ironforge |
| 8–11 | Darkshore |
| 11–13 | Deeprun Tram, Westfall, Redridge Mountains |
| 13 | The Deadmines, Wailing Caverns |
| 13–15 | Class quests ≤ 20 |

## Phase 3 — Levels 20–30 → release 0.5
| Batch | Content |
|---|---|
| 16–18 | Ashenvale, Wetlands |
| 19–22 | Rest of Darkshore and Loch Modan, Stonetalon Mountains, Redridge, Duskwood, Westfall, The Barrens |
| 23–25 | Blackfathom Deeps, The Stockade, Shadowfang Keep, Gnomeregan, Razorfen Kraul |

## Phase 4 — Levels 30–45 → releases 0.6–0.7
| Batch | Content |
|---|---|
| 25–29 | Hillsbrad Foothills, Arathi Highlands, Thousand Needles, Desolace |
| 30–33 | Stranglethorn Vale, Duskwood, Alterac Mountains, Dustwallow Marsh |
| 34–36 | Swamp of Sorrows, Badlands, Feralas, Tanaris, The Hinterlands |
| 37–38 | Searing Gorge, Scarlet Monastery, Razorfen Downs, Uldaman, Zul'Farrak, Maraudon |

## Phase 5 — Completing levels 1–45 → release 0.8
| Batch | Content |
|---|---|
| 38–41 | Stormwind City, Northshire, Elwynn Forest |
| 42–45 | All class quests up to level 45 |
| 45–50 | Professions, battlegrounds, events, leftovers |

## WoW Forever (from 4 November 2026)
- **Launch week:** play with Speurtocht.NL on and send any Lua errors. Check whether the quest IDs match Classic, using `/speur status` and the *tekst gewijzigd* flag.
- **Ongoing:** after play sessions, run `tools/capture_to_json.py` and send the file. New Forever quests (the Cozy Sleeping Bag chain and others) become extra batches, slotted in where they fit in the leveling route.

## Phase 6 — Alliance levels 46–60 → release 0.9
- Set `max-level: 60` in `route.txt`, add the endgame zones and dungeons, then replan.
- Covers Un'Goro, Felwood, Winterspring, the Plaguelands, Burning Steppes, Blasted Lands, Azshara and Silithus.
- Dungeons and raids: Blackrock Depths and Spire, Dire Maul, Scholomance, Stratholme, Sunken Temple, Molten Core, Onyxia and Blackwing Lair attunements.

## Phase 7 — Public release 1.0
- Choose a license for the code and the translations.
- Publish on CurseForge, which also makes the addon findable in WowUp.
- Automated release zips from git tags (GitHub Actions + BigWigs packager, using `.pkgmeta`).
- Readme screenshots, plus an English/Dutch switch for the addon's own interface text.
- An issue template so players can report translation mistakes.

## Phase 8 — Horde
- Replan with Horde starting zones (Valley of Trials, Deathknell, Red Cloud Mesa) and the Horde leveling route.

## Speeding up later phases (optional)
Phases 6–8 add about 100 batches. Chat sessions are the right tool while the style is still being tuned on your own play-testing. Once it's settled, the same batch files can be produced with a script that calls the Claude API (with batch processing), running unattended. The importer's checks stay the same, so quality control doesn't change. See https://docs.claude.com/en/api/overview.
