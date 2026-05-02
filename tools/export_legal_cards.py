#!/usr/bin/env python3
"""
Export deck-legal cards from core/card_battle/card_db.gd ALL_CARDS to CSV/XLSX.

Legal = every ALL_CARDS entry except summon tokens (id starts with "token_").
max_copies_deck mirrors CardDB.card_copy_max (see card_db.gd).
"""

from __future__ import annotations

import csv
import json
import os
import sys

DECK_SIZE_MAX = 30
DECK_COPY_MAX = 2

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD_DB = os.path.join(PROJECT_ROOT, "core", "card_battle", "card_db.gd")
EXPORT_DIR = os.path.join(PROJECT_ROOT, "exports")
CSV_PATH = os.path.join(EXPORT_DIR, "legal_cards.csv")
XLSX_PATH = os.path.join(EXPORT_DIR, "legal_cards.xlsx")

HEADERS = [
    "id",
    "name",
    "type",
    "subtype",
    "cost",
    "mana_value",
    "atk",
    "hp",
    "rarity",
    "max_copies_deck",
    "ability",
    "ability_desc",
    "effect",
    "value",
    "no_pack",
    "set",
    "set_number",
    "desc",
]


def parse_all_cards(text: str) -> list[dict]:
    start = text.index("const ALL_CARDS = [")
    end = text.index("\n## ── Flavor text", start)
    block = text[start:end]
    cards: list[dict] = []
    for raw_line in block.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if not line.startswith("{"):
            continue
        line = line.removesuffix(",").strip()
        line = line.removesuffix(", ]").strip()
        cards.append(json.loads(line))
    return cards


def max_copies_deck(card: dict) -> int:
    aid = str(card.get("ability", ""))
    if aid == "skeleton_horde":
        return DECK_SIZE_MAX
    if "dark_lotus" in aid:
        return 1
    if str(card.get("rarity", "")) == "legendary":
        return 1
    return DECK_COPY_MAX


def is_deck_legal_entry(card: dict) -> bool:
    return not str(card.get("id", "")).startswith("token_")


def row_dict(card: dict) -> dict[str, object]:
    out = {h: card.get(h, "") for h in HEADERS}
    out["max_copies_deck"] = max_copies_deck(card)
    return out


def write_csv(rows: list[dict]) -> None:
    os.makedirs(EXPORT_DIR, exist_ok=True)
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=HEADERS, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def write_xlsx(rows: list[dict]) -> bool:
    try:
        from openpyxl import Workbook
    except ImportError:
        return False
    os.makedirs(EXPORT_DIR, exist_ok=True)
    wb = Workbook()
    ws = wb.active
    ws.title = "legal_cards"
    ws.append(HEADERS)
    for r in rows:
        ws.append([r.get(h, "") for h in HEADERS])
    wb.save(XLSX_PATH)
    return True


def main() -> int:
    text = open(CARD_DB, "r", encoding="utf-8").read()
    cards = parse_all_cards(text)
    rows = [row_dict(c) for c in cards if is_deck_legal_entry(c)]
    write_csv(rows)
    print(f"Wrote {CSV_PATH} ({len(rows)} rows)")
    if write_xlsx(rows):
        print(f"Wrote {XLSX_PATH}")
    else:
        print("openpyxl not installed; skipped .xlsx (pip install openpyxl)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
