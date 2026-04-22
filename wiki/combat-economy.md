# Combat Economy

**Summary**: Resource model for card battles, including mana generation via pitch, cost payment, and redraw cadence.  
**Sources**: `raw/card-game.md`, `raw/card-game-ai.md`  
**Last updated**: 2026-04-22

---

## Core Resources

Cards have mana costs and require payment to play (source: `raw/card-game.md`).  
Any hand card may be pitched for +1 mana, making hand-to-mana conversion central to each turn (source: `raw/card-game.md`).

## Pitch Cycle

Pitched cards are collected and moved to deck bottom in randomized order at end turn (source: `raw/card-game.md`).  
This creates a cyclical economy where pitch choices can influence late-cycle deck texture (source: `raw/card-game.md`).

## Tempo Baselines

Going second grants an extra free mana at start, smoothing response tempo (source: `raw/card-game.md`).  
AI guidance recommends spending all mana when possible and choosing stronger outcomes from threat evaluation (source: `raw/card-game-ai.md`).

## Hand Reset Pressure

Since hand is discarded/redrawn to 5 at end turn, unspent resources usually expire unless placed in arsenal (source: `raw/card-game.md`).

See also: [[arsenal-system]], [[battle-flow]].

## Related pages

- [[arsenal-system]]
- [[battle-flow]]
- [[ai-behaviors]]
