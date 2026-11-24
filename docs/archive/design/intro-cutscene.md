# Intro Cutscene

## Goal

Show a one-time introductory cutscene the first time the player presses Play and transitions to the level select screen. Acts as a brief game intro. Never shown again once dismissed.

## Affected files

| File | Change |
|------|--------|
| `data/cutscenes/world_0.lua` | New — intro beats (placeholder content) |
| `lua/game/scenes/start_scene.lua` | `_advance()` checks seen flag; routes through cutscene on first visit |
| `tests/ui/08_intro_cutscene.lua` | New UI spec covering first-visit and repeat-visit paths |

## What changes

**Progress tracking** — the existing `_seen_cutscene` table already supports any numeric key. `0` is used as the intro ID, so `Progress.is_cutscene_seen(0)` / `mark_cutscene_seen(0)` work without any changes to `progress.lua` or the save format.

**Cutscene data** — `data/cutscenes/world_0.lua` returns a beats table in the same format as `world_2.lua` / `world_3.lua`. Placeholder content (e.g. "SYSTEM" speaker) is fine for now.

**StartScene._advance()** — before switching to `LevelSelectScene`, check the intro seen flag. If unseen, mark it seen and switch to `CutsceneScene.new(0, next_level_select, scene_manager)`. `CutsceneScene` already builds the path as `data/cutscenes/world_0.lua`; no change needed there.

**UI spec** — `tests/ui/08_intro_cutscene.lua` covers:
1. First visit: pressing Enter on StartScene triggers cutscene, advancing past it lands on level select.
2. Second visit (intro already seen): pressing Enter goes straight to level select.
3. Escape on intro cutscene skips to level select.

## What stays the same

- `CutsceneScene` itself — no code changes needed; it already handles world_num = 0 via the path format.
- `progress.lua` — no changes; numeric key `0` is already valid.
- Save file format — `0` serialises cleanly alongside other cutscene indices.
- World entry cutscenes (worlds 2, 3, …) — untouched.
- `_unlock_all` path in `StartScene` — goes straight to level select, skipping intro (same as today; appropriate for the debug shortcut).

## Open questions

None — user confirmed content doesn't matter, only that the cutscene fires on first visit.
