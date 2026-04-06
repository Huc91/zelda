#!/usr/bin/env python3
"""
How many of *your* end-turn refreshes until deck-out, with pitch + extra draws?

Model (matches Zelda flow in spirit):
  - You start each turn with 5 cards in hand (from last refresh).
  - During the turn you draw R extra cards from the deck (spell / battlecry).
    Each extra draw reduces the deck by 1 before refresh math.
  - You pitch P cards (0..5) back into the deck before the refresh; they do not go to GY.
  - You play K cards from hand; those leave the hand and are treated as leaving the
    recycle loop (GY / board) — they do not return to deck for this sim.
  - Constraint: P + K <= 5 + R (cards moved out of hand cannot exceed hand size).

End of turn:
  - Effective deck before drawing the new hand: D' = D - R + P
  - If D' < HAND (5): deck-out this refresh.
  - Else: D'' = D' - HAND.

Monte Carlo over random (P, K, R) policies.
"""
from __future__ import annotations

import random
from dataclasses import dataclass

HAND = 5


@dataclass
class Policy:
    """Tunable knobs — adjust to taste."""
    # Extra draws per turn: weighted choices (0 = none, 1 = bolt/draw1, 2 = dark pact-ish)
    r_weights: tuple[int, ...] = (60, 25, 15)
    # Pitch count: sample from this range after drawing R (uniform on indices)
    p_min: int = 1
    p_max: int = 3
    # Plays: uniform 0..k_max, then clip to hand budget
    k_max: int = 2


def one_turn(deck: int, pol: Policy, rng: random.Random) -> tuple[int, bool]:
    """Return (deck_after_refresh, decked_out)."""
    r = rng.choices([0, 1, 2], weights=list(pol.r_weights), k=1)[0]
    d = deck - r
    hand = HAND + r
    p = rng.randint(pol.p_min, pol.p_max)
    k = rng.randint(0, pol.k_max)
    if p + k > hand:
        # If policy infeasible, pitch first then play with what's left
        p = min(p, hand)
        k = min(hand - p, k)
    before_draw = d + p
    if before_draw < HAND:
        return d, True
    return before_draw - HAND, False


def simulate(
    d0: int,
    pol: Policy,
    trials: int = 20_000,
    max_turns: int = 80,
    seed: int = 42,
) -> dict:
    rng = random.Random(seed)
    turns: list[int] = []
    for _ in range(trials):
        d = d0
        for t in range(1, max_turns + 1):
            d, dead = one_turn(d, pol, rng)
            if dead:
                turns.append(t)
                break
        else:
            turns.append(max_turns)  # censored
    turns.sort()
    def pct(p: float) -> float:
        return turns[int(p * (len(turns) - 1))]
    return {
        "d0": d0,
        "mean_turns": sum(turns) / len(turns),
        "p10": pct(0.10),
        "p50": pct(0.50),
        "p90": pct(0.90),
    }


def main():
    # Opening hand: deck starts at D0 - HAND
    for d0 in (20, 30):
        start = d0 - HAND
        print(f"\n=== Built deck {d0} cards → deck after mulligan {start} ===")
        for label, pol in [
            ("light pitch P∈[0,2], light draw", Policy(p_min=0, p_max=2, r_weights=(70, 22, 8))),
            ("typical P∈[1,3], some draw", Policy()),
            ("heavy pitch P∈[2,4], few draw", Policy(p_min=2, p_max=4, r_weights=(80, 15, 5))),
            ("spam draw R weighted 2", Policy(r_weights=(40, 35, 25))),
        ]:
            s = simulate(start, pol)
            print(
                f"  {label:32}  mean {s['mean_turns']:.1f} turns  "
                f"p10–p90 {s['p10']:.0f}–{s['p90']:.0f}  "
                f"(median {s['p50']:.0f})"
            )


if __name__ == "__main__":
    main()
