# Implementig UI Source

**Summary**: Detailed card-battle UI and interaction specification tied to Figma references. Covers interactions, states, visual cues, and HUD behavior.  
**Sources**: `raw/implementig-ui.md`  
**Last updated**: 2026-04-22

---

## Primary Reference

The card battle screen is specified via Figma, with multiple frames and detailed behavior notes (source: `raw/implementig-ui.md`).

## Core Interaction Model

- Direct attack control is disabled unless legal (source: `raw/implementig-ui.md`)
- Battle log must be scrollable and auto-scroll to latest event (source: `raw/implementig-ui.md`)
- Hovering a card updates the zoomed card panel with full details (source: `raw/implementig-ui.md`)
- Player hand is visible; enemy hand is represented numerically (source: `raw/implementig-ui.md`)
- Drag from hand to zones determines front/back summon placement (source: `raw/implementig-ui.md`)
- Right click or drag-to-status-bar can pitch a card (source: `raw/implementig-ui.md`)

## Combat UX

Attacks are represented by arrows: select attacker, then click target (source: `raw/implementig-ui.md`).  
Possible targets include monsters and direct attack when legal (source: `raw/implementig-ui.md`).  
A selected card gets a green outline and contextual action buttons such as Move and Effect (source: `raw/implementig-ui.md`).

See also: [[battle-flow]], [[board-positioning]].

## State Indicators

Summoning sickness/exhausted cards look disabled and show `ZZZ` (source: `raw/implementig-ui.md`).  
Damaged cards display life in red (source: `raw/implementig-ui.md`).  
A turn circle indicator is green on player turn and red on enemy turn (source: `raw/implementig-ui.md`).

## Card Visual Rules

Top-right and mini-card corner indicate mana cost (source: `raw/implementig-ui.md`).  
Rarity jewels and border colors map as common grey, rare blue, epic purple, legendary orange (source: `raw/implementig-ui.md`).  
Demon card background is `F4E4D9`; spell card background is `A1B467` (source: `raw/implementig-ui.md`).  
Mini-card names are trimmed to 8 chars with ellipsis; if card has an effect, mini text shows `Effect` (source: `raw/implementig-ui.md`).

## Modal/Toast Behaviors

Deck and grave are inspectable via modal views (deck order random when viewed) (source: `raw/implementig-ui.md`).  
Toasts notify turn changes, battle start/end, and win/loss (source: `raw/implementig-ui.md`).

## Arsenal UX Notes

Cards can be dragged to arsenal, and arsenal choice can also be made from hand at end turn (source: `raw/implementig-ui.md`).  
This may overlap with dedicated once-per-turn arsenal rules from [[card-game-source]] and should be validated during implementation (source: `raw/implementig-ui.md` and source: `raw/card-game.md`).

## Related pages

- [[battle-ui-spec]]
- [[battle-flow]]
- [[board-positioning]]
- [[arsenal-system]]
