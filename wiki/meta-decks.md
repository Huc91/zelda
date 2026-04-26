# Meta Decks

**Summary**: Three curated archetypes for hard AI enemies and bosses, each with a distinct win condition and AI strategy instructions.

**Sources**: `raw/meta-decks.md`, `raw/meta-decks-screen/deathping.png`, `raw/meta-decks-screen/terrorspell.png`, `raw/meta-decks-screen/reanimator.png`

**Last updated**: 2026-04-26

---

## Death Ping

**Win condition**: Get Death Knell (`demon_030`) into the rear row and protect it. Spam cheap deathrattle/death-trigger bodies to the front. Every demon death drains 1 HP from the enemy. Flood the board, trade aggressively, and accumulate ping damage.

**Key cards**:
- `demon_030` Death Knell (×2) — cornerstone; must hit rear row
- `demon_046` Grave Glutton (×2) — grows on every death
- `demon_047` Carrion Beetle — gains mana on ally death
- `demon_077` Hellfire Imp (×2) — deathrattle draw
- `demon_051` Necrotic Wisp (×2) — deathrattle buff all
- `demon_040` Imp Matron (×2) — summons extra body
- `spell_008` Resurrection — refuels cheap-body spam from GY
- `spell_016` Summon Familiar (×2) — 0-cost body
- `spell_017` Final Hour — late-game board flood

**AI type**: `death_ping`

**AI strategy**:
- Death Knell is detected as a support demon (`any_death_drain`) → automatically placed in rear row
- Priority engine gives Death Knell +600 bonus if not yet on board
- Cheap demons (cost ≤ 2) get +120 priority to maximize bodies on board
- Resurrection gets +250 priority when GY contains cheap fodder
- Stash logic unchanged — stashes unplayable expensive cards normally

---

## Tidal Terror

**Win condition**: Flood the graveyard with cheap spells. Each spell reduces Tidal Terror's cost by 1 (min 0). Pyromancer deals 1 AoE to all enemy demons whenever a spell is cast. Use the spell-AoE engine to clear the board, then land a free Tidal Terror.

**Key cards**:
- `demon_083` Tidal Terror (×2) — win condition; costs 7 base, reduced by spells in GY
- `demon_075` Pyromancer (×2) — AoE engine; protected in rear row
- `demon_007` Fallen Goddess — battlecry draw 2 to accelerate spell count
- `demon_048` Echo Scholar — replays last spell for free
- `spell_048` Cantrip (×2), `spell_026` Bolt (×2), `spell_036` Ember Rain (×2) — cheap GY fillers
- `spell_019` Dark Lotus — 0-cost +3 mana burst
- `spell_039` Disruption — bounce strongest enemy demon

**AI type**: `tidal_terror`

**AI strategy**:
- All spells get +180 priority bonus to build GY fast
- Tidal Terror is held (−999 priority) until effective cost ≤ 2, then gets +500 bonus
- Pyromancer now recognized as support demon (`spell_aoe` added to `demon_is_support`) → goes to rear row
- Pyromancer gets bonus proportional to number of spells in hand
- Effective cost for Tidal Terror is computed from actual spell GY count (`_enemy_effective_cost`)
- Enemy mana deduction uses effective cost, not raw cost

---

## Reanimator

**Win condition**: Discard fat demons to the graveyard at end of turn (hold them unplayed). Use Resurrection and Final Hour to reanimate. Final Hour destroys all your demons then refills all slots from GY — perfect reset. Chaos King Dragon requires 3 Obscura + 3 Regalia in GY and deals 2 damage per card in enemy GY.

**Key cards**:
- `demon_044` Chaos King Dragon — legendary finisher; needs 3 Obscura + 3 Regalia in GY
- `spell_017` Final Hour — ideal arsenal card; floods board from GY
- `spell_008` Resurrection — single-target reanimate
- `demon_043` Chimera (×2) — 10/12/12; primary GY target
- `demon_042` Demon Lord — 8/8; primary GY target
- `demon_059` Undying Fiend (×2) — deathrattle returns to hand
- `demon_026` Thousand Eyes (×2) — pitcher + draw 2; enable big plays
- `demon_024` Arcane Tome (×2) — pitcher; safe to pitch

**AI type**: `reanimator`

**AI strategy**:
- `_stash_candidate_index` always stashes Final Hour first if in hand (highest priority over all other logic)
- Fat demons (cost ≥ 5) are protected from being pitched (`pitch_keep_weight` +800)
- Big demons get −300 priority when no reanimate spells are left in GY (forces them to discard naturally)
- Resurrection priority scales with the best-value demon in GY (cost × 10 + stats)
- Final Hour gets +400 bonus once GY has 3+ demons, blocked (−500) before that threshold
- Chaos King Dragon blocked (`is_enemy_card_playable`) until enemy GY has ≥3 Obscura AND ≥3 Regalia

---

## Assigning Meta Decks

Use `CardDB.meta_deck("archetype_name")` in a boss or hard enemy actor's `get_battle_deck()` method:

```gdscript
func get_battle_deck() -> Array:
    return CardDB.meta_deck("death_ping")   # or "tidal_terror" / "reanimator"
```

The AI type is auto-detected from the deck by `detect_ai_type_from_deck` — no manual wiring needed.

## Related pages

- [[ai-behaviors]]
- [[combat-economy]]
- [[arsenal-system]]
- [[battle-flow]]
