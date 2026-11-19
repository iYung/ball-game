# Cutscene Engine Checklist

- [x] Task A — `game/progress.lua` — Add `_seen_cutscene` set persisted in the save file. Update `_persist` to write `{solved={...}, cutscenes={...}}` and `_load` to read either the new format or the old plain-array format (backward compat). Expose `Progress.is_cutscene_seen(w)` and `Progress.mark_cutscene_seen(w)`.

- [x] Task B — `data/cutscenes/world_2.lua`, `data/cutscenes/world_3.lua` — Create placeholder cutscene data files (one per non-first world). Each returns a list of beat tables: `{bg={r,g,b}, speaker="NAME", portrait="name", text="..."}`. Use 2–3 beats per world with atmospheric placeholder text.

- [ ] Task C — `game/scenes/cutscene_scene.lua` — Implement the cutscene scene engine. Constructor: `CutsceneScene.new(world_num, next_scene, scene_manager)`. Loads beats from `data/cutscenes/world_N.lua`. Draws: full-screen bg color, text box panel (bottom 220px), speaker name label, dialogue text, portrait slot (right side of text box — tries `assets/portraits/<name>.png`, falls back to a code-drawn rounded rect with consistent hue from name hash and centred first letter). Input: Enter/Space/click advances to next beat or switches to `next_scene`; Escape immediately switches to `next_scene`.

- [ ] Task D — `game/scenes/level_select_scene.lua` — In `_cycle_world(delta)`, after the new `self._world` is chosen, check: if `self._world ~= 1` and `love.filesystem.getInfo("data/cutscenes/world_N.lua")` and `not Progress.is_cutscene_seen(self._world)`, then mark seen and push `CutsceneScene` → `LevelSelectScene` (pre-set to the new world). Return early so normal rebuild doesn't run until after the cutscene.

- [x] Task E — `tests/test_progress.lua` — Add tests for `is_cutscene_seen` / `mark_cutscene_seen`: unseen by default, seen after mark, persists across a mock reload.
