# Wiki Log

**Summary**: Append-only record of wiki ingestion and update operations.  
**Sources**: `raw/card-game.md`, `raw/card-game-ai.md`, `raw/implementig-ui.md`, `raw/game-mechanics.md`, `raw/on-the-art.md`, `raw/lore.md`, `core/card_battle/card_db.gd`  
**Last updated**: 2026-04-22

---

- 2026-04-22: Initial wiki creation from raw sources. Added 6 source-summary pages (`card-game-source`, `card-game-ai-source`, `implementig-ui-source`, `game-mechanics-source`, `on-the-art-source`, `lore-source`). Added 14 concept pages covering combat rules, AI, UI, progression, soul systems, art constraints, and lore entities/timeline. Created `wiki/index.md` table of contents and linked pages with `[[wiki-links]]` throughout.
- 2026-04-22: Corrected deck size in `card-game-source` from 30 to implementation value 20 after checking game files. Added explicit note documenting mismatch between `raw/card-game.md` design text and `core/card_battle/card_db.gd` runtime constant (`DECK_SIZE_MAX := 20`). Updated `wiki/index.md` sources accordingly.
- 2026-04-22: Updated lore continuity notes after author clarification that `Roger` is the renamed continuation of `Zeno`. Removed ambiguity wording in `lore-source` and `zeno-and-homo-psy`.
