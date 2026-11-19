# World Select

## Goal

Group the 16 puzzles into named "worlds" and let players tab between them in the level-select screen via a top bar, instead of seeing all puzzles in one flat list.

## Affected files

- `game/puzzle_loader.lua` — add world definitions (groups of puzzle indices + world name)
- `game/scenes/level_select_scene.lua` — replace the flat list with a world-tabbed layout

## What changes

### World definitions (`puzzle_loader.lua`)

Add a `WORLDS` table that maps world names to ranges of puzzle indices. All worlds are always unlocked (no progression gating). The grouping is intentionally easy to change.

Initial grouping (placeholder — will be tweaked):

| World | Name | Puzzles |
|-------|------|---------|
| 1 | Basics | 01–05 |
| 2 | Combos | 06–11 |
| 3 | Advanced | 12–16 |

New API surface:
- `PuzzleLoader.world_count()` → number of worlds
- `PuzzleLoader.world(w)` → `{ name, puzzles = { {index, name}, … } }`

The existing `PuzzleLoader.load(n)` and `PuzzleLoader.count()` are unchanged so the rest of the game is unaffected.

### Level-select screen (`level_select_scene.lua`)

**Top bar — world selector**

A horizontal bar near the top of the screen showing one tab per world (e.g. `< BASICS >` with left/right arrows). Left/Right arrow keys (and left/right mouse clicks on the arrows) cycle through worlds. The selected world name is highlighted.

**Level list**

Below the top bar, same visual style as today, but only showing the levels that belong to the selected world. The level index shown to the player is the global puzzle number (e.g. 06) so it stays consistent with the existing game.

**Keyboard navigation**

| Key | Action |
|-----|--------|
| Left / Right | Cycle worlds |
| Up / Down | Move selection within the world |
| Enter / Space | Play selected level |
| Esc | Back to start screen |

When switching worlds, the cursor resets to the first level of the new world.

**Mouse**

Clicking the `<` / `>` arrows in the world bar cycles worlds (same as Left/Right). Clicking a row selects and plays that level (same as today).

## What stays the same

- `MatrixScene` receives a global puzzle index — no change there
- All 16 puzzle files are untouched
- `StartScene` navigates to `LevelSelectScene` — no change
- `PuzzleLoader.load(n)` / `PuzzleLoader.count()` signatures unchanged
- Visual palette / color scheme stays consistent with the rest of the UI

## Open questions

- None blocking implementation. World names and groupings are placeholder; the design is built to make them trivial to change in `puzzle_loader.lua`.
