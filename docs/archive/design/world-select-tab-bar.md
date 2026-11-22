# World Select Tab Bar

## Goal

Replace the left/right arrow world-switcher in `LevelSelectScene` with a horizontal tab bar at the top of the screen. Each world gets its own tab; locked worlds show a padlock icon in place of their name.

## Affected files

- `lua/game/scenes/level_select_scene.lua` — all visual and input changes live here
- `tests/ui/03_world_locking.lua` — UI spec that asserts world-switching behaviour; must be updated for tab element IDs
- `tests/ui/02_level_select_keyboard.lua` — keyboard navigation spec; check if arrow-key world switch assertions need updating

## What changes

### Layout

- Remove the centred name + `<`/`>` arrow buttons (currently at `BAR_Y = 100`).
- Remove the world dots row below the bar (currently at `dot_y = bar_y + bar_h + 10`).
- Add a tab bar across the full width of the screen at the very top (`TAB_Y = 0`, `TAB_H ≈ 48`).
  - Each tab is `W / world_count` wide.
  - The active tab has a highlighted background and a coloured bottom-edge underline.
  - Locked tabs show a padlock glyph (`🔒` or `[X]` if the font lacks the glyph) instead of the world name.
  - Locked tabs are visually dimmed and do not respond to clicks or keyboard selection.
- The puzzle list moves up to fill the freed space (`LIST_TOP` adjusted accordingly).

### Interaction

- **Mouse click** on an unlocked tab → switch to that world (same `_cycle_world` logic, just target the index directly instead of cycling ±1; cutscene behaviour is preserved).
- **Left/Right arrow keys** still cycle through unlocked worlds (existing behaviour preserved).
- Locked tabs are excluded from keyboard cycling (already the case via `_cycle_world`).

### `ui_elements()` registry

Replace `world:prev` / `world:next` buttons with one button per world:

```
{ id = "world:1", label = "Basics",       kind = "button", ... }
{ id = "world:2", label = "Combos",       kind = "button", ... }
{ id = "world:3", label = "Advanced",     kind = "button", ... }
{ id = "world:4", label = "Transforms",   kind = "button", ... }
{ id = "world:5", label = "Fixed Pieces", kind = "button", ... }
```

Locked tabs have `enabled = false`. The UI spec in `tests/ui/03_world_locking.lua` must switch from asserting `assert_text = "WORLD 2: COMBOS"` to clicking `world:2`.

## What stays the same

- `_cycle_world(delta)` logic (skip locked, trigger cutscene first visit) — reused when left/right keys are pressed, and called with an absolute target from tab clicks.
- Keyboard up/down puzzle navigation.
- Enter to load selected puzzle.
- Escape to return to start screen.
- All `puzzle:N` element IDs and row rendering.

## Open questions

None — locked worlds show a padlock icon (user confirmed).
