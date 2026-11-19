# Start Screen + Level Select

## Goal

Add a start screen and a level-select screen so the game has a proper entry point and players can pick any puzzle. Puzzle completion returns to level select instead of advancing automatically.

## Affected files

- `main.lua` — boot into `StartScene` instead of `MatrixScene`
- `game/scenes/start_scene.lua` — new: title screen, "Press any key" or single Play button
- `game/scenes/level_select_scene.lua` — new: navigable list of all puzzles
- `game/scenes/matrix_scene.lua` — accept `scene_manager` + `puzzle_index`; on win switch back to level select; Escape exits to level select

## What changes

### `main.lua`
- Replace `MatrixScene.new()` with `StartScene.new(manager)` as the first scene.

### `game/scenes/start_scene.lua` (new)
- Draws title text "MATRIX PUSH" in large font, centred.
- Subtitle / tagline below it.
- A single prompt: `[Enter]  Play` (or any key).
- Key handler: any `keypressed` → switch to `LevelSelectScene`.
- Mouse handler: any click → switch to `LevelSelectScene`.
- Pure code drawing, no image assets needed.

### `game/scenes/level_select_scene.lua` (new)
- Receives `scene_manager`.
- Lists all puzzles by name (from `PuzzleLoader`) in a vertical menu.
- Up/Down arrows move selection; Enter/Space loads selected puzzle.
- Mouse hover highlights the puzzle row under the cursor; click loads it.
- Escape goes back to `StartScene`.
- Draws current selection highlighted.
- No completion tracking in this iteration (all puzzles always available).

### `game/scenes/matrix_scene.lua`
- `MatrixScene.new(puzzle_index, scene_manager)` — `scene_manager` is optional for backward compatibility.
- On `status == "win"`, after the final animation, switch to `LevelSelectScene` (if `scene_manager` present).
- Escape key: switch to `LevelSelectScene` (was: no binding).
- Remove left/right arrow puzzle cycling (that's level select's job now).

## What stays the same

- All puzzle logic, grid, HUD, timeline — untouched.
- `SceneManager` and `Scene` base — untouched.
- Puzzle data files — untouched.

## Open questions

None.
