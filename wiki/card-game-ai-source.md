# Card Game AI Source

**Summary**: Defines tactical priorities and deck-style AI behavior profiles for card battles.  
**Sources**: `raw/card-game-ai.md`  
**Last updated**: 2026-04-22

---

## Global Heuristics

The AI should use min-max style evaluation and try to spend all available mana when possible (source: `raw/card-game-ai.md`).  
It should prioritize stronger plays and evaluate threats/outcomes before deciding moves (source: `raw/card-game-ai.md`).

## Behavior Profiles

- Aggro: prioritize face pressure and high summon tempo (source: `raw/card-game-ai.md`)
- Control: prioritize removals and neutralizing biggest threats (source: `raw/card-game-ai.md`)
- Ramp: prioritize mana acceleration and large-unit deployment (source: `raw/card-game-ai.md`)
- Midrange: balanced line between pressure and control (source: `raw/card-game-ai.md`)

See also: [[ai-behaviors]], [[battle-flow]], [[board-positioning]].

## Related pages

- [[ai-behaviors]]
- [[battle-flow]]
- [[board-positioning]]
