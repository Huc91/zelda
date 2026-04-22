# Art Direction

**Summary**: Minimal but strict visual direction anchored to Game Boy Color-like 16x16 tile and sprite granularity.  
**Sources**: `raw/on-the-art.md`  
**Last updated**: 2026-04-22

---

## Pixel Density Rule

All base world tiles are `16x16` (source: `raw/on-the-art.md`).  
Character sprites are also `16x16` (source: `raw/on-the-art.md`).

## Implementation Implications

Movement, collision, and UI iconography should preserve clean pixel readability at this base scale (needs verification).  
Any scaling pipeline should avoid blurring and preserve crisp nearest-neighbor output (needs verification).

## Related pages

- [[battle-ui-spec]]
- [[on-the-art-source]]
