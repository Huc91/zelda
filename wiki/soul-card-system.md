# Soul Card System

**Summary**: Inventory model replacing classic A/B item slots with three color-coded soul equipment channels.  
**Sources**: `raw/game-mechanics.md`  
**Last updated**: 2026-04-22

---

## Slot Model

The system has three fixed slots: red, blue, green (source: `raw/game-mechanics.md`).  
Red is generally offensive tools, blue is traversal/metroidvania utility, green is battle buffs (source: `raw/game-mechanics.md`).

## Acquisition and Scope

Soul cards are found in overworld or via soul-catching mechanics; they are not currently in packs (source: `raw/game-mechanics.md`).  
Current implementation scope is limited to migrating the sword into this system (source: `raw/game-mechanics.md`).

## HUD and Menu Impact

A/B HUD slots should be replaced with three soul icons, and equip management should be available in menu flow (source: `raw/game-mechanics.md`).  
The source references GUI assets inside `GUI_plugin` for icon usage (source: `raw/game-mechanics.md`).

## Related pages

- [[inventory-and-hud]]
- [[world-progression]]
- [[game-mechanics-source]]
