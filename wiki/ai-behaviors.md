# AI Behaviors

**Summary**: Tactical AI profiles for different deck identities, sharing common threat-evaluation and mana-efficiency priorities.  
**Sources**: `raw/card-game-ai.md`  
**Last updated**: 2026-04-22

---

## Shared Policy

AI should evaluate outcomes (min-max style), prioritize stronger lines, and spend mana efficiently each turn (source: `raw/card-game-ai.md`).

## Profiles

### Aggro

Aggro pushes face pressure and swarm-like board occupation by summoning many demons (source: `raw/card-game-ai.md`).

### Control

Control emphasizes board cleanup, removal usage, and deleting the largest opposing threats (source: `raw/card-game-ai.md`).

### Ramp

Ramp aims to accelerate mana and deploy bigger demons earlier (source: `raw/card-game-ai.md`).

### Midrange

Midrange balances aggression and control response lines (source: `raw/card-game-ai.md`).

## Related pages

- [[battle-flow]]
- [[board-positioning]]
- [[combat-economy]]
