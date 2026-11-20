# Cutscene Engine

## Goal

Add a visual-novel-style cutscene engine that plays once per world the first time the player enters it. The cutscene content is data-driven so it can be changed independently of the engine.

## Affected files

| File | Role |
|------|------|
| `game/scenes/cutscene_scene.lua` | New scene — the engine |
| `data/cutscenes/world_N.lua` | New data files — one per world that has a cutscene |
| `game/progress.lua` | Add `is_cutscene_seen(w)` / `mark_cutscene_seen(w)` |
| `game/scenes/level_select_scene.lua` | Trigger cutscene on first entry to a world |

## What changes

### 1. `game/progress.lua`

Add a second set stored alongside `_solved`:

```lua
local _seen_cutscene = {}  -- set: _seen_cutscene[w] = true
```

Persist it in the same `progress.lua` save file by writing a second line:

```lua
return {solved={1,2,3,...}, cutscenes={2,3,...}}
```

(Old saves that return a plain array stay compatible — treat them as the `solved` list.)

New API:
- `Progress.is_cutscene_seen(w)` → bool
- `Progress.mark_cutscene_seen(w)` → persists

### 2. `data/cutscenes/world_N.lua`

One file per world that should have a cutscene (world 1 has none; worlds 2+ get one).

Each file returns a list of **beats**:

```lua
return {
  {
    bg       = {0.05, 0.03, 0.12},   -- RGB background fill
    speaker  = "SYSTEM",             -- name shown above dialogue box
    text     = "New challenges await.",
  },
  { ... },
}
```

Fields are all optional — omitting `speaker` hides the name bar; omitting `text` shows a blank box (useful for silent atmosphere beats); omitting `bg` reuses the previous beat's color.

### 3. `game/scenes/cutscene_scene.lua`

A standard `Scene`-subclass. Constructor:

```lua
CutsceneScene.new(world_num, next_scene, scene_manager)
```

- `world_num`: integer, used only to load `data/cutscenes/world_N.lua`
- `next_scene`: scene instance to switch to when the cutscene ends

State machine: `beat_idx` (1-based), `fade_alpha` for per-beat fade-in.

Layout (1280×720):
- Full-screen background color from the beat
- Text box: bottom 220px, semi-transparent dark panel, left-aligned text
- Speaker name: small label above the text box left edge
- Advance hint: `[Enter / Click]  Continue   [Esc]  Skip` — bottom-right corner of text box

Input:
- `Enter`, `Space`, `mouse_pressed` → advance to next beat; on last beat → `scene_manager:switch(next_scene)`
- `Escape` → immediately `scene_manager:switch(next_scene)` (skip all)

**Portrait slot** — right side of the text box (or above it), ~180×220px.

- Beat data references a portrait by name: `portrait = "narrator"`
- Engine tries to load `assets/portraits/<name>.png`; if the file is absent or not yet created it draws a **code-rendered placeholder**: a styled rounded rectangle filled with a consistent hue derived from the name, with the first letter of the name centred in it
- This means portraits are always visually present — art drops in by adding the PNG, no code change needed

### 4. `game/scenes/level_select_scene.lua`

In `_cycle_world(delta)`, after updating `self._world`, add:

```lua
local w = self._world
if w ~= 1 and not Progress.is_cutscene_seen(w) then
    local cs_path = string.format("data/cutscenes/world_%d.lua", w)
    if love.filesystem.getInfo(cs_path) then
        Progress.mark_cutscene_seen(w)
        local CutsceneScene = require("game/scenes/cutscene_scene")
        local LevelSelectScene = require("game/scenes/level_select_scene")
        local next = LevelSelectScene.new(self.scene_manager)
        next._world = w          -- land on the new world after the cutscene
        self.scene_manager:switch(CutsceneScene.new(w, next, self.scene_manager))
        return
    end
end
```

`mark_cutscene_seen` is called *before* switching so a crash mid-cutscene doesn't replay it.

## What stays the same

- `SceneManager` — no changes; cutscene is just another scene
- `Progress.mark_solved` / `is_world_unlocked` — untouched
- All existing puzzle/world data
- Save-file format is extended backward-compatibly

## Open questions

None — scope is clear. Cutscene content (text, colors) is placeholder; the engine is the deliverable.
