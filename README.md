# Zelda Card Game

A Zelda-like overworld with a card battle system built in Godot 4 (GDScript).

## Dev Mode

Dev mode gives access to all cards and 9999 rupies for playtesting.

**Three ways to enable it:**

1. **Code flag** — open `core/global.gd` and set:
   ```gdscript
   const _DEV_OVERRIDE: bool = true
   ```

2. **Env var** — launch Godot from terminal:
   ```bash
   ZELDA_DEV=1 godot .
   ```

3. **CLI arg**:
   ```bash
   godot -- --dev
   ```

Set `_DEV_OVERRIDE` back to `false` (or remove the env var) to test as a normal player. Your real collection and rupies are preserved when switching modes.
