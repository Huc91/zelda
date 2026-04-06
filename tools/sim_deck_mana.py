#!/usr/bin/env python3
"""Monte Carlo: compare 20 vs 30-card starter-style decks for pitch/mana dynamics."""
from __future__ import annotations

import random
from dataclasses import dataclass


@dataclass(frozen=True)
class C:
    cost: int
    mv: int
    kind: str  # "demon" | "spell"


# Current Zelda 20-card player list (cost / mana_value): 6×1 6×2 6×3 demons + 2×1 spells.
DECK_20: list[C] = (
    [C(1, 1, "demon")] * 6
    + [C(2, 1, "demon")] * 6
    + [C(3, 1, "demon")] * 6
    + [C(1, 1, "spell")] * 2
)

# Historical 30-card player list = current 20 + these 10 extras.
DECK_30: list[C] = DECK_20 + [
    C(4, 1, "demon"),  # demon_017
    C(4, 1, "demon"),  # demon_012
    C(0, 1, "spell"),  # spell_016
    C(1, 1, "spell"),
    C(1, 1, "spell"),  # spell_013 x2
    C(2, 1, "spell"),  # spell_005
    C(2, 1, "spell"),  # spell_001
    C(1, 1, "spell"),  # spell_007
    C(2, 1, "spell"),  # spell_003
    C(1, 1, "spell"),  # spell_011
]


def draw_hand(deck: list[C], k: int = 5) -> list[C]:
    return random.sample(deck, k)


def bloodungeon_plays(hand: list[C], max_plays: int = 2, taxed: int = 0) -> int:
    """Greedy play count using BD-style net cost = eff_cost + manaValue; demons cap by board 8 omitted."""
    budget = sum(c.mv for c in hand)
    cand = sorted(
        hand,
        key=lambda a: (
            0 if a.kind == "demon" else 1,
            -((a.cost + taxed) if a.kind == "spell" else a.cost),
        ),
    )
    plays = 0
    for c in cand:
        if plays >= max_plays:
            break
        eff = (c.cost + taxed) if c.kind == "spell" else c.cost
        net = eff + c.mv
        if net <= budget:
            budget -= net
            plays += 1
    return plays


def sim(deck: list[C], trials: int = 50_000):
    hands = [draw_hand(deck) for _ in range(trials)]
    costs = [sum(x.cost for x in h) for h in hands]
    mvs = [sum(x.mv for x in h) for h in hands]
    mins_c = [min(x.cost for x in h) for h in hands]
    maxs_c = [max(x.cost for x in h) for h in hands]
    plays = [bloodungeon_plays(h) for h in hands]
    return {
        "n": len(deck),
        "E_sum_cost": sum(costs) / trials,
        "E_sum_mv": sum(mvs) / trials,
        "E_min_cost": sum(mins_c) / trials,
        "E_max_cost": sum(maxs_c) / trials,
        "P_min_cost_ge_4": sum(1 for m in mins_c if m >= 4) / trials,
        "E_bd_plays": sum(plays) / trials,
        "P_bd_2_plays": sum(1 for p in plays if p >= 2) / trials,
    }


def main():
    random.seed(42)
    a = sim(DECK_20)
    b = sim(DECK_30)
    print("Metric                        20-card    30-card")
    print("-" * 52)
    for key in [
        "n",
        "E_sum_cost",
        "E_sum_mv",
        "E_min_cost",
        "E_max_cost",
        "P_min_cost_ge_4",
        "E_bd_plays",
        "P_bd_2_plays",
    ]:
        print(f"{key:28} {a[key]!s:>10} {b[key]!s:>10}")


if __name__ == "__main__":
    main()
