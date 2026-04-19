---
name: Session 19 Apr — Implementation Progress
description: All 8 features from implementation-19apr.md implemented, headless checks pass
type: project
---

## Status: COMPLETE (as of session 19 Apr 2026)

All features from `core/ui/implementation-19apr.md` implemented and passing headless Godot checks.

**Why:** User asked to implement all features and not stop until done.
**How to apply:** Check these areas if bugs arise; new saves needed (old saves break on load).

### Features implemented

1. **Enemy pathfinding** — `octorok.gd` rewritten with state_chase using `Map.nav_find_path()`. `humanoid.gd` already had it.

2. **Soul System** — `core/soul_item.gd` (SoulItem class), souls in `Global.SOULS` dict, equip/unequip, soul_collection + caught_souls tracking. 4 souls: sword (red), stone (blue, +1 maxHP), tree (green, +4 battle heal), flower (green, +1 luck).

3. **HUD** — `core/ui/hud.gd` rewritten: 3 colored soul slot indicators (red/blue/green) replace A/B slots.

4. **Soul Inventory UI** — `core/ui/soul_inventory.gd`: press I to open, arrow keys navigate, X equips, Z unequips. Press I again for deck builder.

5. **Attack = X / Interact = Z** — `attack` and `interact` actions added to project.godot. player.gd uses `attack` for red soul weapon, `interact` for soul catching. NPC and bonfire use `interact`.

6. **Luck stat** — `Global.get_total_luck()` + `roll_luck()`. Luck = equipped soul bonuses + foil card count, clamped 0–42. Used in: grass drops, money rewards (+10), initiative (+1).

7. **Initiative dice screen** — `core/ui/initiative_screen.gd`: 1s rolling animation, result shown 2s, +3 attacker bonus, +1 luck bonus, lethal/skirmish label. Shows before each battle.

8. **Soul catching** — Z key near tiles: checks STATIC layer `soulable` custom data (stone/tree) and DYNAMIC `is_cuttable` (flower). Auto-equips if slot empty.

9. **HP system** — 12HP = 3 hearts, quarter-heart granularity. Battle HP = Global.player_hp (synced start+end). Easy/normal loss → 1HP. Hard/boss loss → game over. Post-battle tree soul heals.

### Files created
- `core/soul_item.gd`
- `core/ui/initiative_screen.gd`
- `core/ui/soul_inventory.gd`

### Files modified
- `core/global.gd` (rewrite: HP system, soul system, luck)
- `project.godot` (attack + interact actions)
- `data/actors/player/player.gd` (soul-based attack/interact)
- `data/actors/npc/npc.gd` (interact action)
- `data/actors/bonfire.gd` (interact action)
- `core/ui/hearts.gd` (quarter hearts)
- `core/ui/hud.gd` (soul slot icons)
- `core/ui/inventory.gd` (guard: check visible before processing)
- `core/ui/ui.gd` (soul inventory, remove broken item_received)
- `core/main.gd` (initiative screen, HP sync, battle consequences, luck reward)
- `core/map.gd` (luck grass drops, get_soulable_type, show_label)
- `core/card_battle/card_battle.gd` (HP linkage, heal cap)
- `data/actors/enemies/octorok.gd` (pathfinding state machine)
- `core/pickup.gd` (soul_id-based pickup)

### Known designer tasks (code-ready, needs editor work)
- Mark tree/rock tiles with `soulable = "tree"` / `soulable = "stone"` custom data in tileset editor — flower tiles already detected via `is_cuttable`
- Add soul icons to `GUI_plugin/` and wire them up in `Global._init_souls()`
