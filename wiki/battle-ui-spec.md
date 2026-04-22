# Battle UI Spec

**Summary**: Consolidated UX/UI behavior for the card battle screen with strict interaction, state, and readability requirements.  
**Sources**: `raw/implementig-ui.md`, `raw/on-the-art.md`  
**Last updated**: 2026-04-22

---

## Layout and Readability

The battle UI is tied to a Figma reference and should preserve detailed interaction intent (source: `raw/implementig-ui.md`).  
Zoom panel is the main location for full card text readability on hover (source: `raw/implementig-ui.md`).

## Interaction Contracts

- Drag card to front/back play zones to summon in corresponding row (source: `raw/implementig-ui.md`)
- Right click hand card or drag to status bar to pitch (source: `raw/implementig-ui.md`)
- Select attacker then target via arrow flow (source: `raw/implementig-ui.md`)
- Contextual card actions include Move and Effect when legal (source: `raw/implementig-ui.md`)

## State and Feedback

Battle log must auto-scroll to latest event (source: `raw/implementig-ui.md`).  
Toasts communicate important phase events (turn changes, battle start/end, result) (source: `raw/implementig-ui.md`).  
Turn indicator circle is green for player and red for enemy turn (source: `raw/implementig-ui.md`).

## Visual Rules

Card backgrounds: demon `F4E4D9`, spell `A1B467` (source: `raw/implementig-ui.md`).  
Rarity mapping: common grey, rare blue, epic purple, legendary orange (source: `raw/implementig-ui.md`).  
Mini-card naming: max 8 chars with ellipsis; show `Effect` label when effect exists (source: `raw/implementig-ui.md`).

## Pixel Scale

Art uses `16x16` tile/sprite constraints in Game Boy Color style (source: `raw/on-the-art.md`).  
UI assets should respect nearest-neighbor clarity and integer placement where required by implementation constraints (needs verification).

## Related pages

- [[battle-flow]]
- [[board-positioning]]
- [[art-direction]]
