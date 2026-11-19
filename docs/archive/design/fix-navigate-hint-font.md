# Fix: Navigate Hint Text Font Compatibility

## Goal
Replace Unicode arrow characters in the puzzle select screen hint text with ASCII equivalents that the default LOVE2D font supports.

## Affected files
- `game/scenes/level_select_scene.lua` — line 145, the hint text string

## What changes
The hint text at the bottom of the puzzle select screen currently reads:

```
[↑↓] Navigate   [Enter] Play   [Esc] Back
```

The `↑` and `↓` characters are Unicode (U+2191, U+2193) and are not rendered by the default LOVE2D font — they appear as blank boxes or are silently dropped.

Replace them with ASCII-safe alternatives. Options:
- `[Up/Down]` — most readable, matches LOVE2D key names
- `[^/v]` — compact but cryptic

**Decision:** Use `[Up/Down]` for clarity and consistency with how other keybinding hints read in the codebase (e.g. `[Enter]`, `[Esc]`).

## What stays the same
- Font sizes and font loading
- Layout, colors, and positioning of all hint text
- All other hint tokens (`[Enter]`, `[Esc]`)
- No new font files needed

## Open questions
None — ASCII-only replacement is straightforward.
