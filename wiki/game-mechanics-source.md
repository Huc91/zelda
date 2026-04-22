# Game Mechanics Source

**Summary**: High-level game loop description, progression structure, and early inventory-to-soul-system migration requirements.  
**Sources**: `raw/game-mechanics.md`  
**Last updated**: 2026-04-22

---

## Core Game Structure

The game combines Zelda-like exploration with card battles (source: `raw/game-mechanics.md`).  
The world is an archipelago of 5 islands with one boss per island plus a final boss (source: `raw/game-mechanics.md`).

## Progression and Exploration

Powerups gate traversal, enabling metroidvania-style backtracking into previously blocked areas (source: `raw/game-mechanics.md`).  
Card acquisition includes both packs and hidden overworld discoveries (source: `raw/game-mechanics.md`).

## Initiative Layer

Card combat includes a real-time pre-battle initiative advantage based on who strikes first before battle begins (source: `raw/game-mechanics.md`).

See also: [[battle-flow]], [[world-progression]].

## Card Soul System

Items are reframed as soul cards with 3 fixed slots: red, blue, green (source: `raw/game-mechanics.md`).  
Red slot is typically offense, blue is traversal powers, green is battle buffs (source: `raw/game-mechanics.md`).  
For now, only sword is implemented and should move into this soul system (source: `raw/game-mechanics.md`).

HUD should replace A/B slots with three small soul-item icons, and an equipment menu should support swapping equipped souls (source: `raw/game-mechanics.md`).  
The note references GUI assets in `GUI_plugin` as icon source (source: `raw/game-mechanics.md`).

See also: [[soul-card-system]], [[inventory-and-hud]].

## Related pages

- [[world-progression]]
- [[battle-flow]]
- [[soul-card-system]]
- [[inventory-and-hud]]
