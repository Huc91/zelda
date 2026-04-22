# Battle Flow

**Summary**: End-to-end battle turn structure spanning initiative context, card economy, attacks, and state transitions.  
**Sources**: `raw/card-game.md`, `raw/card-game-ai.md`, `raw/implementig-ui.md`, `raw/game-mechanics.md`  
**Last updated**: 2026-04-22

---

## Pre-Battle Initiative

A real-time encounter layer influences initiative advantage in the card battle that follows (source: `raw/game-mechanics.md`).

## Turn Economy

Cards require mana to play and can be pitched for +1 mana (source: `raw/card-game.md`).  
AI policy emphasizes using available mana and selecting high-value lines (source: `raw/card-game-ai.md`).

See also: [[combat-economy]], [[ai-behaviors]].

## Hand Lifecycle

Players do not draw at turn start; instead, they redraw to 5 at end turn and discard remaining hand cards (source: `raw/card-game.md`).

## Summon and Position

Demons are played into front/rear rows with different combat permissions (source: `raw/card-game.md`).  
Drag-drop UI placement maps directly to target zone for row assignment (source: `raw/implementig-ui.md`).

See also: [[board-positioning]].

## Attack Sequence

User flow: select attacker, arrow appears, then select legal target (source: `raw/implementig-ui.md`).  
Rear targeting is conditional on cleared front line; direct attacks are only legal in valid states (source: `raw/card-game.md` and source: `raw/implementig-ui.md`).

## State Transitions

Freshly summoned or used cards can be exhausted and shown as disabled with `ZZZ` state marker (source: `raw/implementig-ui.md`).  
Damage and threat visibility are reinforced by UI cues (red life text, arrows, type bonus text) (source: `raw/implementig-ui.md`).

## Related pages

- [[combat-economy]]
- [[board-positioning]]
- [[battle-ui-spec]]
- [[ai-behaviors]]
