# Matrix Circuit

## Goal

A SpaceChem-style puzzle game where the player programs a 2D circuit grid to transform
an input matrix into a target matrix using elementary matrix operations. Each puzzle has
a fixed input and target; the player wins by routing a "cursor" through the grid so it
applies the right sequence of operations.

---

## Core Mechanic

The play area is a **10×10 grid**. Two fixed cells are given per puzzle:

- **Source** (green): the cursor spawns here carrying the input matrix, moving in the
  source's preset direction.
- **Sink** (blue): when the cursor enters this cell, its current matrix is compared to
  the target. Match → win; mismatch → fail.

The player fills the grid with two kinds of tiles:

### Arrow tiles
Redirect the cursor: `→ ← ↑ ↓`. The cursor always moves one cell per step in the
direction the current cell's arrow points. If a cell has no tile, the cursor keeps its
current heading (blank = straight-through). Reaching the grid boundary is an error.

### Operation tiles
Applied to the matrix when the cursor passes through. Each has configurable parameters
set via a small pop-up when placed:

| Tile | Symbol | Effect | Params |
|------|--------|--------|--------|
| Transpose | `T` | Swap rows and columns | — |
| Scale Row | `×` | Multiply one row by a scalar | row index, scalar (integer or fraction) |
| Add Rows | `R+` | Add a multiple of one row to another | src row, dst row, scalar multiplier |
| Swap Rows | `↔` | Exchange two rows | row A, row B |
| Negate | `−` | Multiply entire matrix by −1 | — |
| Scalar Mul | `S×` | Multiply entire matrix by a scalar | scalar |

These are the six elementary/near-elementary linear-algebra operations — enough to
express Gaussian elimination, transposition, reflection, and scaling.

### Cursor loop detection
If the cursor visits the same cell twice in one run, the run is flagged as an infinite
loop and halted.

---

## UI Layout (1280×720)

```
┌────────────────────────────────────────────────────────────────────┐
│  MATRIX CIRCUIT           Puzzle 3 of 10         [Run] [Step] [Reset]│
├──────────────────────────┬─────────────────────────────────────────┤
│                          │  INPUT              TARGET               │
│   10×10 GRID             │  ┌──────────┐      ┌──────────┐         │
│   (tiles placed here)    │  │ 1  0  2  │      │ 2  1  0  │         │
│                          │  │ 3  1  4  │  →   │ 4  3  1  │         │
│                          │  │ 0  0  1  │      │ 1  0  0  │         │
│                          │  └──────────┘      └──────────┘         │
│                          ├─────────────────────────────────────────┤
│                          │  CURRENT STATE (live during step/run)   │
│                          │  ┌──────────┐                           │
│                          │  │ ...      │                           │
│                          │  └──────────┘                           │
├──────────────────────────┴─────────────────────────────────────────┤
│  PALETTE:  [→] [←] [↑] [↓]  |  [T] [×] [R+] [↔] [−] [S×]  [🗑 Erase]│
└────────────────────────────────────────────────────────────────────┘
```

**Left panel (800×600):** the grid. Cells are ~72px each. Tiles drawn as colored
rounded rectangles with a symbol label. The cursor is a bright highlight that moves
during run/step.

**Right panel (480×720):** input matrix, target matrix, and the live "current state"
matrix that updates as the cursor steps through operations.

**Bottom bar:** palette — click a tile to select it, then click/drag on the grid to
place it. Right-click to erase. Selected palette tile is highlighted.

---

## Interaction Model

- **Click palette tile** → arm the brush with that tile type.
- **Click grid cell** → place the armed tile. If the tile has params, open a small
  parameter pop-up (number inputs). Confirm closes it.
- **Right-click grid cell** → erase tile.
- **[Run]** → animate the cursor at ~4 cells/sec. Matrix display updates after each op.
  Win/fail shown at Sink.
- **[Step]** → advance cursor by one cell.
- **[Reset]** → return cursor to Source, restore input matrix, keep placed tiles.
- **ESC** → back to puzzle select screen (tiles preserved).

---

## Puzzle Format (data files)

Each puzzle is a Lua table in `data/puzzles/`:

```lua
return {
    name   = "Row Reverse",
    grid_w = 10, grid_h = 10,
    source = { x=1, y=5, dir="right" },
    sink   = { x=10, y=5 },
    input  = {
        rows = 2, cols = 2,
        values = { {1,0}, {0,1} }
    },
    target = {
        rows = 2, cols = 2,
        values = { {0,1}, {1,0} }
    },
    -- optional: locked tiles the player cannot remove
    locked = {
        { x=3, y=5, type="arrow", dir="right" },
    }
}
```

---

## Puzzle Progression (initial set, 10 puzzles)

| # | Name | Matrix | Concept taught |
|---|------|--------|---------------|
| 1 | Identity Check | 2×2 | Straight wire, no ops (tutorial) |
| 2 | Flip It | 2×2 | Transpose |
| 3 | Sign Change | 2×2 | Negate |
| 4 | Row Swap | 2×2 | Swap rows |
| 5 | Scale Up | 2×2 | Scale a row |
| 6 | Row Reduce | 3×3 | Add rows |
| 7 | Double Flip | 2×2 | Loop: apply transpose twice |
| 8 | Combo | 3×3 | Chain multiple ops |
| 9 | U-Turn | 3×3 | Arrow routing + ops |
| 10 | Elimination | 3×3 | Full row reduction chain |

---

## Affected Files

New files (all under `game/`):

```
game/scenes/matrix_scene.lua    Main scene: grid, run loop, UI layout
game/grid.lua                   10×10 tile grid: place/erase/query
game/cursor.lua                 Cursor: position, heading, step logic
game/matrix_math.lua            Matrix type + 6 operations (pure Lua, no deps)
game/palette.lua                Palette bar: selection, brush state
game/param_popup.lua            Small parameter editor (row index, scalar)
game/puzzle_loader.lua          Load puzzle tables, validate, expose input/target
game/hud.lua                    Right-panel: input/target/current state display
data/puzzles/01_identity.lua    ... through ...
data/puzzles/10_elimination.lua
```

Existing files touched:

```
main.lua        Switch initial scene to MatrixScene (or add scene select)
conf.lua        Update window title to "Matrix Circuit"
```

---

## What Changes

- The existing `GameScene` / `Player` / coin demo is replaced (or hidden behind a scene
  flag) by `MatrixScene`.
- `matrix_math.lua` is pure Lua with no Love2D dependency — testable headlessly.
- The `Sprite` / `Drawer` / `Camera` / `Scene` / `Timer` / `Input` core is reused
  as-is; the grid and HUD draw directly via `love.graphics` calls inside the scene.

## What Stays the Same

- All `lua/core/` modules: Scene, Drawer, Camera, Sprite, Timer, Input.
- `main.lua` canvas/scaling setup.
- Headless test runner.
- Folder layout conventions.

---

## Open Questions

None — all answered before doc was written.
