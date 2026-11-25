# Puzzle Editor

## Goal

A visual puzzle editor reachable from the start screen. The designer places source, sink, gaps and locked op tiles on a 10×10 grid, edits the input and target matrices, picks the op allowlist, then copies the puzzle Lua to the clipboard. Pasting Lua back into the editor re-loads a previous draft. A Test button opens the in-progress puzzle in MatrixScene for play-testing; Menu returns to the editor.

## Affected files

| File | Change |
|---|---|
| `lua/game/scenes/editor_scene.lua` | **New** — the full editor |
| `lua/game/scenes/start_scene.lua` | Add "Editor" button, wire to EditorScene |
| `lua/game/scenes/matrix_scene.lua` | Add optional `back_scene` arg; "Menu" returns to it when present |
| `tests/ui/12_editor.lua` | **New** — UI spec |

Nothing else changes. EditorScene does not touch PuzzleLoader, Progress, or save data.

## What changes

### StartScene

A fourth UI element `start:editor` (label "Editor") is added below Unlock All. The start scene gets a new `_editor_rect` and routes clicks on it to `EditorScene.new(scene_manager)`.

### EditorScene (new scene)

**Layout** (1280×720, same grid constants as MatrixScene):

```
 ┌─────────────────────────────────┐  ┌──────────────────────────┐
 │       10×10 grid                │  │  HUD (x=820, w=460)      │
 │  GRID_X=95  GRID_Y=20           │  │  ─ Name field            │
 │  CELL_SIZE=63                   │  │  ─ INPUT matrix editor    │
 │                                 │  │    rows/cols spinners     │
 │                                 │  │    value cells (click ±1) │
 │                                 │  │  ─ ↓ divider              │
 │                                 │  │  ─ TARGET matrix editor   │
 │                                 │  │  ─ Op allowlist toggles   │
 └─────────────────────────────────┘  └──────────────────────────┘
 ┌─────────────────────────────────────────────────────────────────┐
 │  Palette: [SRC] [SNK] [GAP] | all ops… | [Mv] [X] | [Lock ●]  │
 │                                 [Test]  [Copy]  [Paste]  [Back] │
 └─────────────────────────────────────────────────────────────────┘
```

**Grid editing**

- Palette tools: Source, Sink, Gap, every op (same list as MatrixScene's `PALETTE_BUTTONS`), Drag/Move, Erase.
- A Lock toggle button (`editor:lock`) in the palette bar. When active, newly placed op tiles have `locked=true`. Source, Sink and Gap are always locked.
- Right-click on a cell erases it (same as MatrixScene).

**Matrix editors (HUD)**

- Two sections: INPUT and TARGET.
- Each section has `[-] rows [+]` and `[-] cols [+]` spinners (1–4 each).
- Matrix values are displayed as a grid of cells. Clicking the left third decrements the value by 1; clicking the right third increments; clicking the centre opens a simple "enter digit" mode (love.textinput). Values are clamped to –9…9.
- Changing rows/cols on the INPUT matrix also adjusts param max clamps in the editor (same logic as MatrixScene:load_puzzle).

**Name field**

- A text input area in the HUD. Clicking it focuses it; love.textinput appends characters; Backspace removes the last one; Enter/Escape unfocuses.

**Op allowlist panel**

- A compact list of all op names in the HUD, below the target matrix.
- Each entry is a toggle button (`editor:allow:<op>`). When enabled, the op goes into the exported `ops = { … }` list. When all are disabled (or none toggled), the export omits the `ops` field entirely (meaning all ops are available, matching the game's default behaviour).

**Copy**

Serializes the current editor state to a Lua string identical in shape to the existing `data/puzzles/*.lua` files, calls `love.system.setClipboardText(src)`, and shows a brief "Copied!" flash on screen.

Serialization rules:
- `locked` list: every non-source, non-sink, non-gap anchor tile on the grid, in row-major order.
- `gaps`: all gap tiles.
- `source`, `sink`: their grid coords.
- `input`, `target`: current matrix dimensions and values.
- `ops`: the enabled op allowlist (omitted if all ops are toggled on or none is toggled).
- `name`: the name field text (default `"Untitled"`).
- `grid_w = 10, grid_h = 10` always.

**Paste**

Calls `love.system.getClipboardText()`, runs `local ok, def = pcall(load("return " .. text))`, and if successful loads `def` into the editor state (same path as a fresh load). Shows "Parse error" on failure. This resets all editor state to match the pasted definition.

**Test**

Builds a puzzle table from the current editor state (same as Copy but as a Lua table, not a string) and switches to `MatrixScene.new_from_def(def, scene_manager, editor_scene)`. The editor scene instance is passed as the third arg so MatrixScene can return to it.

### MatrixScene — back_scene support

`MatrixScene.new` gains an optional fourth parameter `back_scene`. When set, the "Menu" command calls `scene_manager:switch(back_scene)` instead of going to LevelSelectScene. The `_cmd_activate("menu")` path is the only change.

A new factory `MatrixScene.new_from_def(puzzle_def, scene_manager, back_scene)` accepts a plain puzzle table instead of a numeric index. Internally it stores the def on `self._custom_puzzle` and `load_puzzle` uses it instead of calling `PuzzleLoader.load`.

## What stays the same

- MatrixScene gameplay, palette, timeline — no changes except the back_scene hook.
- PuzzleLoader and all existing puzzle data files.
- LevelSelectScene, SolutionRecapScene, CutsceneScene.
- Progress, save, settings.

## Open questions

None. All decisions resolved before design:
- Export via clipboard only (copy button → setClipboardText; paste button → getClipboardText).
- Full tile placement with lock toggle.
- Test button opens MatrixScene; Menu in that session returns to the editor.
