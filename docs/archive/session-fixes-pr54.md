## Session Fixes PR #54 Checklist

- [x] Guard `Save.read()` — `lua/core/save.lua` — add `love.filesystem.getInfo("save.dat")` check before `love.filesystem.read` so the call is skipped on first load (web build no longer errors on missing save file)
- [x] Guard `Save.read_settings()` — `lua/core/save.lua` — same `getInfo` guard before reading `settings.dat`
- [x] Restore ESC keybinding doc (level-select) — `README.md` — change "Return to start screen" back to "Open settings"
- [x] Restore ESC/Menu keybinding doc (puzzle) — `README.md` — change "Return to level select (from puzzle) or start screen (from level select)" back to "Open settings overlay (SFX / music volume, Resume, Exit to Menu)"
- [x] Restore timeline row-scroll doc — `README.md` — re-add the `Click ^ / v in timeline` row that PR #52 had dropped
- [x] Clear next-world cutscene flag in `unlock_world` — `lua/game/progress.lua` — set `_seen_cutscene[w + 1] = nil` after marking puzzles solved so pressing U always resets the first-visit cutscene for the newly-accessible world
- [x] Add UI spec for U-key cutscene reset — `tests/ui/06_cutscene.lua` — "pressing u to unlock world 1 resets world 2 cutscene": starts with no `cutscenes_unseen` (all pre-marked seen), presses U, clicks world:2 tab, asserts cutscene fires
