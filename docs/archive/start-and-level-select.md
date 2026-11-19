# Start Screen + Level Select Checklist

- [x] Task A — `main.lua` — Replace `MatrixScene.new()` boot with `StartScene.new(manager)`; require the new scene file
- [x] Task B — `game/scenes/start_scene.lua` — Create new scene: draws title "MATRIX PUSH" + tagline centred; any keypressed or mouse click switches to `LevelSelectScene`
- [x] Task C — `game/scenes/level_select_scene.lua` — Create new scene: vertical list of all puzzle names from `PuzzleLoader`; Up/Down + mouse hover to highlight; Enter/Space/click to load puzzle in `MatrixScene`; Escape returns to `StartScene`
- [x] Task D — `game/scenes/matrix_scene.lua` — Accept optional `scene_manager` second arg to `MatrixScene.new()`; on `status == "win"` switch to `LevelSelectScene`; Escape switches to `LevelSelectScene`; remove left/right arrow puzzle cycling
