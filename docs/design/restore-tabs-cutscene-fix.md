## Goal

Restore the tab-bar world selector in level select (accidentally reverted by PR #52) and
add a UI spec that proves tab-clicks trigger cutscenes on first visit to a world.

## Background

PR #47 replaced the left/right arrow bar with per-world clickable tabs and introduced
`_switch_world(target)` so both keyboard navigation and direct tab clicks go through the
same cutscene-check code path.

PR #48 added the settings overlay and built on top of the tab bar correctly (blob `83f976e`).

PR #52 (100% coverage) was developed against an outdated checkout that pre-dated the tab
bar.  When merged it clobbered level_select_scene.lua back to the arrow-bar version and
updated every test file to match, losing:
- The tab-bar UI (`world:N` elements, `_tab_rects`, `_switch_world`, `world_index_of`)
- The settings overlay integration (`SettingsMenu`, `settings_state`, Sound music start)
- `assert_button` tab assertions across six test files

Additionally, no UI spec ever tested the mouse path `click world:N tab → cutscene` —
only the keyboard path `press = "right"` → `_cycle_world` → `_switch_world` was exercised.

## Affected files

| File | Change |
|---|---|
| `lua/game/scenes/level_select_scene.lua` | Restore to blob `83f976e` (tabs + settings overlay) |
| `tests/test_level_select.lua` | Restore tab-based assertions; add right-click no-op test |
| `tests/ui/01_solve_puzzle_1.lua` | Restore `assert_button { id = "world:1", selected = true }` |
| `tests/ui/03_world_locking.lua` | Restore `assert_button` tab-selection checks |
| `tests/ui/04_sweep_all_puzzles.lua` | Restore `assert_button` world-tab check; restore `click_button settings:exit` after ESC |
| `tests/ui/05_start_screen.lua` | Fix `assert_text "WORLD 2: COMBOS"` → `assert_button { id = "world:2", selected = true }` |
| `tests/ui/02_level_select_keyboard.lua` | Remove "escape returns to start screen" (ESC now opens settings in tab version) |
| `tests/ui/06_cutscene.lua` | Add spec: click world:2 tab (first visit) triggers cutscene |

## What changes

### level_select_scene.lua
- Restore contents to blob `83f976e` verbatim (tabs, `_switch_world`, settings menu, Sound music)

### tests/test_level_select.lua
- Restore blob `9f63832` (tab-based registry/locked-tab assertions)
- Add: "right-click does not switch scene" (uses `world:1` tab, verifies no world switch)

### tests/ui/01_solve_puzzle_1.lua
- Replace `assert_text = "WORLD 1: BASICS"` with `assert_button = { id = "world:1", selected = true }`

### tests/ui/03_world_locking.lua
- Replace `assert_text "WORLD 1: BASICS"` / `assert_no_text "WORLD 2"` with
  `assert_button { id = "world:1", selected = true }` / `assert_button { id = "world:2", selected = false }`
- Replace `assert_text "WORLD 2: COMBOS"` with `assert_button { id = "world:2", selected = true }`

### tests/ui/04_sweep_all_puzzles.lua
- Replace `assert_text string.format("WORLD %d: %s", ...)` with
  `assert_button { id = string.format("world:%d", w), selected = true }`
- Restore `click_button = { id = "settings:exit" }` step after `press = "escape"`

### tests/ui/05_start_screen.lua
- Replace both `assert_text = "WORLD 2: COMBOS"` with `assert_button = { id = "world:2", selected = true }`

### tests/ui/02_level_select_keyboard.lua
- Remove "escape on level select returns to start screen" spec (ESC opens settings overlay)
- Keep "right-click on level select row does nothing"

### tests/ui/06_cutscene.lua
- Add spec: `click_button { id = "world:2" }` with `cutscenes_unseen = { 2 }` → cutscene
  plays, ESC skips, land on world 2 level select.  Covers the mouse path that keyboard
  tests never exercised.

## What stays the same

- All other scenes (matrix, recap, start, cutscene_scene itself)
- Progress / cutscene logic — already correct in `_switch_world`
- The UI runner `given.cutscenes_unseen` mechanism
- All non-level-select test logic

## Open questions

None — the correct file state (blob `83f976e`) is on record and the missing coverage
path is clear.
