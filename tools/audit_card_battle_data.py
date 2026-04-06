#!/usr/bin/env python3
"""
Cross-check `core/card_battle/card_db.gd` against spell resolver and battlecries.

Run from repo root:
  python3 tools/audit_card_battle_data.py

Exits 0 always; prints gaps. Use for manual / CI review.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    db = (ROOT / "core/card_battle/card_db.gd").read_text(encoding="utf-8")
    fx = (ROOT / "core/card_battle/card_battle_spell_effects.gd").read_text(encoding="utf-8")
    battle = (ROOT / "core/card_battle/card_battle.gd").read_text(encoding="utf-8")

    effects = set(re.findall(r'"type":\s*"spell"[^}]*"effect":\s*"([^"]+)"', db, re.DOTALL))
    # Fallback: any "effect": in file (spell rows)
    effects |= set(re.findall(r'"effect":\s*"([^"]+)"', db))

    matched: set[str] = set()
    for line in fx.splitlines():
        if re.match(r"\s+\"", line):
            matched.update(re.findall(r'"([^"]+)"', line))

    unknown_fx = sorted(effects - matched)
    print(f"Spell `effect` tokens in DB: {len(effects)}")
    print(f"Missing from CardBattleSpellEffects.match: {unknown_fx or 'none'}")

    bc = battle[battle.find("func _resolve_battlecry") : battle.find("func _schedule_instant_win")]
    death = battle[battle.find("func _resolve_deathrattle") : battle.find("func _deal_damage_to_player")]

    abilities = set()
    for m in re.finditer(r'"ability":\s*"([^"]*)"', db):
        a = m.group(1).strip()
        if a:
            abilities.add(a)

    missing_bc: list[str] = []
    for a in sorted(abilities):
        if not a.startswith("battlecry_"):
            continue
        ok = f'"{a}"' in bc or any(a in ln and "in ab" in ln for ln in bc.splitlines())
        if not ok:
            missing_bc.append(a)

    missing_dr: list[str] = []
    for a in sorted(abilities):
        if not a.startswith("deathrattle_"):
            continue
        ok = f'"{a}"' in death or any(a in ln and "in ab" in ln for ln in death.splitlines())
        if not ok:
            missing_dr.append(a)

    passive_hints = (
        "haste",
        "poisonous",
        "lifesteal",
        "taunt",
        "unblockable",
        "rage",
        "double_attack",
        "divine_shield",
        "god_card",
        "osiris_piece",
        "mimic_board_count",
        "",
    )
    composites = (
        "haste_poisonous",
        "haste_lifesteal",
        "haste_unblockable",
        "haste_face_mana",
        "haste_face_draw",
        "taunt_poisonous",
        "taunt_lifesteal",
        "taunt_regen",
        "unblockable_lifesteal",
        "haste_taunt",
    )

    missing_passive: list[str] = []
    for a in sorted(abilities):
        if a.startswith(("battlecry_", "deathrattle_", "exhaust_")):
            continue
        if a in passive_hints or a in composites:
            continue
        if "divine_shield" in a and "taunt" in a:  # Ice Barrier
            continue
        if "_" not in a and a in ("haste", "poisonous", "lifesteal", "taunt", "unblockable", "rage", "double_attack", "divine_shield"):
            continue
        # likely custom passive — grep engine
        if a not in battle:
            missing_passive.append(a)

    print(f"\nBattlecry IDs in DB with no `_resolve_battlecry` branch ({len(missing_bc)}):")
    for x in missing_bc:
        print(f"  - {x}")

    print(f"\nDeathrattle IDs in DB with no `_resolve_deathrattle` branch ({len(missing_dr)}):")
    for x in missing_dr:
        print(f"  - {x}")

    print(
        f"\nNon-battlecry/deathrattle ability strings not found in `card_battle.gd` ({len(missing_passive)}):"
        "\n  (Often means passive / aura not wired — verify manually.)"
    )
    for x in missing_passive:
        print(f"  - {x}")


if __name__ == "__main__":
    main()
