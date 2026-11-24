# Music Overlap Fix

## Goal

Stop background music (bg1–bg4) when leaving `MatrixScene` so it does not
overlap with menu music on `StartScene` or `LevelSelectScene`.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `on_exit` and `on_enter`

## What changes

`MatrixScene:on_exit()` currently only calls `self.drawer:clear()`.  It must
also:
1. Fade out whichever bg track is currently playing (`self._bg_track`) over 1 s,
   stopping it when done.
2. Fade in "menu" over 2 s — symmetric with the fade-out that `on_enter`
   applies to menu on the way in.

This mirrors the existing `on_enter` logic (which fades menu out and bg in)
so every scene transition is symmetric.

`LevelSelectScene:on_enter` and `StartScene:on_enter` already call
`Sound.play_music("menu")` when menu is not playing.  After this fix those
guards become redundant but harmless; they can stay.

## What stays the same

- `Sound.fade_music` / `Sound.stop_music` API — no changes.
- `MatrixScene:update` bg-track cycling — unaffected; it only fires while the
  scene is active.
- Settings menu, test suite, all other scenes.

## Open questions

None — the cause and fix are unambiguous from code inspection.
