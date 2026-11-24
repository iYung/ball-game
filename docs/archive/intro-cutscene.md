## Intro Cutscene Checklist

- [x] Task A — `data/cutscenes/world_0.lua` — create intro beats file with placeholder SYSTEM-speaker content (3 beats, same format as world_2.lua)
- [x] Task B — `lua/game/scenes/start_scene.lua` — in `_advance()`, check `Progress.is_cutscene_seen(0)`; if unseen, mark seen and switch to `CutsceneScene.new(0, next_level_select, scene_manager)`; require Progress and CutsceneScene inside the function
- [x] Task C — `tests/ui/08_intro_cutscene.lua` — add UI spec with three cases: (1) first visit triggers cutscene then lands on level select, (2) second visit (intro seen) goes straight to level select, (3) Escape on intro skips to level select
