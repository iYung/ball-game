## Music Overlap Fix Checklist

- [x] Task A — `lua/game/scenes/settings_menu.lua` — In `_on_exit_to_menu()`,
  replace `Sound.fade_music(n, 0, 1)` with `Sound.stop_music(n)` for each bg
  track.  Also update the guard to `if Sound.stop_music then`.  This stops all
  bg tracks immediately before switching scenes, so the destination scene
  (LevelSelectScene / StartScene) can start menu music without any overlap.

- [x] Task B — `tests/ui/10_matrix_scene_settings.lua` — Add a spec that opens
  a puzzle, presses Escape, clicks "Exit to Menu", and asserts the scene has
  returned to level select (e.g. `assert_text = "SELECT PUZZLE"`).  This
  covers the `_on_exit` callback path from MatrixScene settings and verifies
  the navigation completes without error.
