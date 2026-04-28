# Soul Tile Rewards

Maps each `soul_item_id` value (set per-tile in the Godot editor) to what the player receives on a successful absorption.

## How to set up a soulable tile in the editor

1. Select the tile in the TileSet or TileMap.
2. In Custom Data, set **is_soulable** = `true`.
3. Set **soul_item_id** to one of the ids below.
4. Set **soul_absorb_chance** (0.0–1.0). Leave at 0 to default to 100%.

Works on both STATIC and DYNAMIC tilemap layers.

## Soul item ids

| soul_item_id | Name        | Effect                         | Sell price |
|--------------|-------------|--------------------------------|------------|
| `flower`     | Flower Soul | +1 Luck (equipped)             | 3          |
| `stone`      | Stone Soul  | +1 max HP (equipped)           | 5          |
| `tree`       | Tree Soul   | +4 HP healed after battle      | 3          |
| `sword`      | Soul Sword  | Equippable weapon (red slot)   | 5          |

## Intended tile mappings

| Tile type        | Layer   | soul_item_id | absorb_chance |
|------------------|---------|--------------|---------------|
| Flower / grass   | DYNAMIC | `flower`     | 0.6           |
| Rock / stone     | STATIC  | `stone`      | 0.4           |
| Tree             | STATIC  | `tree`       | 0.4           |

## Notes

- You can absorb the same tile multiple times. Each success adds one copy to your collection.
- Extra copies (beyond what you need) can be sold via the Soul Inventory.
- The `soul_absorb_chance` per tile overrides the global default of 1.0.
