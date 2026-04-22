# Card Game Source

**Summary**: Core rules for the Demon Summoner match structure, resources, board rows, and arsenal behavior. Defines the baseline combat system.  
**Sources**: `raw/card-game.md`, `core/card_battle/card_db.gd`  
**Last updated**: 2026-04-22

---

## Match Structure

Matches are usually best-of-1 and intended to be fast (source: `raw/card-game.md`).  
Implemented game rule uses a 20-card deck and 12 life (source: `core/card_battle/card_db.gd`).  
Players draw 5 cards at game start (source: `raw/card-game.md`).

`raw/card-game.md` states 30 cards, which currently conflicts with implementation and should be treated as outdated design text unless gameplay is intentionally reverted (source: `raw/card-game.md` and source: `core/card_battle/card_db.gd`).

## Mana and Pitch

Cards have costs and must be paid with mana to be played (source: `raw/card-game.md`).  
Any card can be pitched for +1 mana (source: `raw/card-game.md`).  
Pitched cards are stacked and shuffled to the bottom of the deck at end of turn (source: `raw/card-game.md`).  
The player going second starts with an extra free mana (source: `raw/card-game.md`).

See also: [[combat-economy]], [[battle-flow]].

## Hand and End Turn

There is no automatic start-of-turn draw; instead, players redraw to 5 at end of turn and unplayed cards are discarded (source: `raw/card-game.md`).

## Arsenal

Once per turn, a player may set one hand card into a face-down arsenal zone (source: `raw/card-game.md`).  
Only one arsenal card can exist at a time (source: `raw/card-game.md`).  
Arsenal cards can be played later but cannot be pitched (source: `raw/card-game.md`).

See also: [[arsenal-system]].

## Board Rows and Targeting

Demons can be in front or rear rows (source: `raw/card-game.md`).  
Front row units can attack and be attacked normally (source: `raw/card-game.md`).  
Rear row units cannot attack and can only be targeted if enemy front is empty (source: `raw/card-game.md`).  
Rear units do not protect face damage; attacking rear is optional when legal (source: `raw/card-game.md`).  
Taunt demons can only be played in front (source: `raw/card-game.md`).

Once per turn, a demon may be moved between front and rear (source: `raw/card-game.md`).

See also: [[board-positioning]], [[battle-flow]].

## Related pages

- [[combat-economy]]
- [[battle-flow]]
- [[arsenal-system]]
- [[board-positioning]]
