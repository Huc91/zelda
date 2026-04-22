# Arsenal System

**Summary**: One-card reserve mechanic that preserves hand value across turns while imposing strict usage limits.  
**Sources**: `raw/card-game.md`, `raw/implementig-ui.md`  
**Last updated**: 2026-04-22

---

## Rule Definition

At end turn (or during turn by allowed flow), one card can be set into arsenal face-down, once per turn (source: `raw/card-game.md`).  
Only one arsenal slot exists; if occupied, no additional card can be added (source: `raw/card-game.md`).

## Restrictions

Arsenal cards can be played later but cannot be pitched for mana (source: `raw/card-game.md`).

## UX Expectations

UI notes include drag-to-arsenal and an end-turn hand choice flow for arsenal assignment (source: `raw/implementig-ui.md`).  
This should be implemented consistently with the one-slot, once-per-turn gameplay rule (source: `raw/card-game.md` and source: `raw/implementig-ui.md`).

## Related pages

- [[combat-economy]]
- [[battle-flow]]
- [[battle-ui-spec]]
