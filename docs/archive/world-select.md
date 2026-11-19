# World Select Checklist

- [x] Task A — `game/puzzle_loader.lua` — Add `WORLDS` table (name + puzzle index ranges) and two new functions: `PuzzleLoader.world_count()` returning the number of worlds, and `PuzzleLoader.world(w)` returning `{ name, puzzles = { {index, name}, … } }` for world `w`. Leave existing `load(n)` and `count()` unchanged.

- [x] Task B — `game/scenes/level_select_scene.lua` — Replace the flat level list with a world-tabbed layout: (1) add `self._world` state (current world index, default 1); (2) add a top bar that renders each world name as a tab, highlighting the selected one with `<` / `>` arrows; (3) filter `self._names` and `self._row_rects` to only the levels in the selected world; (4) wire Left/Right keys to cycle worlds (resetting cursor to 1); (5) wire mouse clicks on `<` / `>` arrows to cycle worlds; (6) update the hint text to include `[Left/Right] Switch World`.
