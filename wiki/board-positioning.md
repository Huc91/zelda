# Board Positioning

**Summary**: Two-row demon battlefield model with front-line gating, rear-line safety, and limited repositioning.  
**Sources**: `raw/card-game.md`, `raw/implementig-ui.md`  
**Last updated**: 2026-04-22

---

## Row Semantics

Front row demons can attack and be attacked normally (source: `raw/card-game.md`).  
Rear row demons cannot attack and are targetable only when enemy front is empty (source: `raw/card-game.md`).

## Targeting Priority

When front enemies exist, attacks must resolve into front line first (source: `raw/card-game.md`).  
If front is empty, legal options include face attack and optional rear attack (source: `raw/card-game.md`).

## Taunt Constraint

Taunt demons can only be played in front row (source: `raw/card-game.md`).

## Reposition Action

A player may move one demon between front and rear once per turn (source: `raw/card-game.md`).  
UI should expose move as contextual action when legal (source: `raw/implementig-ui.md`).

## Related pages

- [[battle-flow]]
- [[battle-ui-spec]]
- [[ai-behaviors]]
