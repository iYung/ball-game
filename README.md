# Matrix Circuit

A SpaceChem-style puzzle game built in Love2D. Program a 2D circuit grid to transform an input matrix into a target matrix using elementary matrix operations. Choose from 23 puzzles, grouped into five worlds, on the level-select screen; completing a puzzle shows a solution recap screen then proceeds to the next puzzle.

## How to play

The play area is a **10×10 grid** with a **Source** (green) and **Sink** (blue) fixed by each puzzle. The Source tile spans the same number of cells as the input matrix (rows × cols), showing exactly where the matrix will sit at the start of a run. The matrix does not move on its own — you place **pushers** and program them on a shared **timeline**. Pushers walk around the board and shove the matrix when they walk into it. Op tiles in its path transform it; any matrix cell touching the Sink ends the run.

**Level select:**

| Key | Action |
|-----|--------|
| `Left / Right` | Switch world |
| `Up / Down` | Navigate puzzle list within world |
| `Enter` | Play selected puzzle |
| `Esc` | Return to start screen |
| Click a row | Play that puzzle |

Puzzles are grouped into five worlds — **Basics** (1–5), **Combos** (6–11), **Advanced** (12–16), **Transforms** (17–20), and **Fixed Pieces** (21–23) — shown in a top bar. Click the `<` / `>` arrows or press Left/Right to cycle worlds. World 1 is always open; every later world is **locked** until all puzzles in the previous world are solved, and locked worlds are skipped when cycling. Click a puzzle row to play it. Hovering highlights a row only when the mouse actually moves, so a resting cursor never overrides Up/Down navigation. On the start screen, press `D` or click **(D) Unlock All** to mark every puzzle solved (useful for testing or jumping ahead).

**In-game controls:**

| Key / Button | Action |
|-------------|--------|
| `R` or **Run** button | Run — one timeline tick at a time, animated (not available while running or after a win) |
| `Space` or **Step** button | Step — advance one tick |
| `Backspace` or **Reset** button | Reset — return the matrix to the source (no-op when there is nothing to reset) |
| `Esc` or **Menu** button | Return to level select (from puzzle) or start screen (from level select) |
| `← →` | Previous / next puzzle |
| Left-click grid | Place selected tile (or pick up a tile in **[Mv]** mode) |
| Right-click grid | Erase tile (or cancel an in-progress drag) |
| Left-click palette | Select a tile type |
| Click `<` / `>` in palette | Scroll the palette one button left / right (only shown when it doesn't fit) |
| Left / right-click timeline slot | Cycle that slot's command forward / back |
| Click `<` / `>` in timeline | Scroll the visible slot window left / right |
| Click `^` / `v` in timeline | Scroll pusher rows up / down (shown when rows overflow the zone) |
| `Esc` | Return to level select (from puzzle) or start screen (from level select) |

The bottom bar spans the full screen width: the palette on the left, **Run**, **Step**, **Reset**, and **Menu** on the right. When the palette doesn't fit, `<` / `>` arrows appear at the edges of the palette section and scroll it one button at a time (an arrow is dimmed when you can't scroll further that way). Your selected tile stays selected while scrolling. Buttons that aren't applicable in the current state are shown dimmed, and the keyboard shortcuts follow the same rules as the buttons. The current puzzle number (`Puzzle N/23`) is shown at the top-left of the right-hand panel.

**Tile types:**

- **P** (Pusher) — a 1×1 mobile unit labelled A–H (up to 8). The tile you place is its start cell. Each tick its timeline command (`^ v < >`, or `.` idle) moves it one cell. Walking into a matrix cell shoves the whole matrix one cell the same way (a pusher starting under the matrix rides along inside it). Any non-idle command that cannot be executed — hitting the grid edge, a gap, another pusher, or trying to shove the matrix when it has nowhere to go — immediately ends the run as **FAIL**. If a transform (e.g. transpose) produces a footprint that extends off the grid, overlaps a gap, or overlaps a pusher, the run also ends as **FAIL**. Idle (`.`) commands never cause a fail. Pushers act in letter order each tick, so A moves before B.
- **×** (Gap) — dark impassable cells placed by the puzzle. Neither pushers nor any part of the matrix can enter them. Some puzzles require reshaping the matrix (e.g. transposing a 2×3 into a 3×2) to fit through a narrow gap corridor.
- **×R** (Scale Row) — vertical tile spanning the matrix's row count; click a band to select the target row, then click left/right thirds of the selected band to adjust the scalar
- **⇅R** (Swap Rows) — 1×2 vertical tile; click left/right thirds of each strip to adjust the row index
- **−I** (Negate) — multiply every element by −1
- **×k** (Scalar Mul) — multiply every element by a scalar
- **+M** (Add Matrix) — element-wise add a constant matrix; expands up to 4×4 via `+`/`−` affordances on the tile edges
- **−M** (Sub Matrix) — element-wise subtract a constant matrix; same resizable grid layout
- **×M** (Mul Matrix) — element-wise multiply by a constant matrix; same resizable grid layout
- **=R** (Set Row) — replace a row with user-defined values; left cell selects the row, additional cells hold the values (expandable up to 4 columns)
- **+R** (Add Rows) — add a scalar multiple of one row to another; 4-cell tile (anchor + src row, dst row, scalar)
- **×Cn** (Scale Col) — horizontal tile spanning the matrix's column count; click a band to select the target column, then click left/right thirds of the selected band to adjust the scalar
- **⇄C** (Swap Cols) — 1×2 horizontal tile; click left/right thirds of each strip to adjust the column index
- **+C** (Add Cols) — add a scalar multiple of one column to another; 4-cell tile
- **=C** (Set Col) — replace a column with user-defined values; top cell selects the column, cells below hold the values
- **R90** (Rotate 90) — rotate every element 90° clockwise; swaps matrix dimensions
- **FLh** (Flip H) — reverse the order of columns (mirror left-right)
- **FLv** (Flip V) — reverse the order of rows (mirror up-down)
- **|x|** (Abs) — replace every element with its absolute value

Click a value cell on any matrix op tile to increment/decrement its value (left/right thirds = −1/+1). Values are clamped to [−9, 9].

Each puzzle only offers the op tiles it needs in the palette (the pusher, **[Mv]** move tool, and eraser are always there).

**Moving tiles:** select **[Mv]** in the palette, then click any unlocked tile to pick it up. A ghost preview follows the cursor — green means the drop is valid, red means the target is occupied or out of bounds. Release the mouse to drop, or right-click to cancel (the tile snaps back to its original position with all parameters intact). Multi-cell tiles (e.g. Scale Row) move as a unit.

Op tiles span one board cell for the op plus one per parameter. Click the left third of a parameter cell for −1 and the right third for +1. An op fires once when the matrix first overlaps any of its cells, and re-arms after the matrix fully leaves.

**Fixed ops:** some puzzles offer ops in two variants — editable (default) and fixed. Fixed ops in the palette are labelled with a `!` suffix (e.g. `xR!`). They can be placed and moved freely but their parameters are preset and cannot be changed. Puzzle-placed fixed ops (shown with a lock icon) are pre-positioned by the puzzle with set parameters; they cannot be moved, erased, or edited.

**Timeline:** the panel in the right column has one row per pusher and `len` slots (default 8, adjustable 1–500, loops). When the loop is longer than the visible window, click `<` / `>` to scroll, or just run — the view auto-scrolls to follow the current slot and rewinds when the loop wraps. Edit it while stopped. Every pusher runs the same loop, so offset the commands to choreograph them.

**Winning:** when any matrix cell touches the Sink and the transformed matrix equals the target, you win. After a brief pause, a **solution recap screen** appears showing the number of ticks your solution took, the number of pieces you placed, and a looping animated playback of your solution — matrix ball and pushers moving in sync — on the board. Click the **Next puzzle**, **Replay**, or **Menu** button (or press `Enter`, `R`, or `Esc`) to advance to the next puzzle, replay the animation, or return to the level-select screen. Clicks outside the three buttons do nothing. A run with no movement for a full timeline loop ends as **STUCK**, and a run past 500 ticks ends as **TIMEOUT**.

**23 puzzles** — from a simple identity check (puzzle 1) through increasingly complex matrix transformations. Puzzles 1–11 each introduce or practice a single operation; puzzles 12–16 require two or three operations in sequence (e.g. transpose then scale, Gaussian elimination, or a three-step chain); puzzles 17–20 introduce the new ops: row reduction, column operations, flips, and absolute value with rotation; puzzles 21–23 introduce fixed ops (player-placed fixed tools and puzzle-placed locked ops; puzzle 21 offers only its fixed `!` ops, no editable ones). Puzzles can use non-square (n×m) matrices.

## Structure

```
lua/core/       Engine classes — no game knowledge (Camera, Drawer, Input, Scene,
                SceneManager, Sprite, SpriteSet, Timer, Fonts)
lua/game/       Game-specific code (Player, Grid, HUD, scenes, etc.)
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner, ui_runner)
tests/          Unit test files — run with: love . --headless
tests/ui/       UI spec files (scripted player sessions), run by the same command
assets/         Images and other assets
conf.lua        Window config; suppresses graphics/audio modules under --headless
main.lua        Entry point — canvas rendering with letterboxing, pixel-art filter
```

## Running

```bash
love .                  # normal window
love . --headless       # run tests and exit
```

## Testing

```bash
love . --headless                                   # all unit tests (tests/*.lua) and UI specs (tests/ui/*.lua)
love . --headless tests/test_worlds.lua             # one unit test file
love . --headless tests/ui/01_solve_puzzle_1.lua    # one UI spec file
love . --headless --coverage                        # all tests + per-file lua/game/ line-coverage report
```

Unit tests print `PASS  tests/x.lua` / `FAIL  tests/x.lua — <error>`. UI specs drive the real scenes headlessly from the title screen (key presses, clicks on named buttons, cells and timeline slots) and print `PASS  tests/ui/x.lua :: <name>` or the failing step and reason. On every frame the runner also checks each scene's UI element registry (`scene:ui_elements()`): every clickable element must be well-formed, on screen, and must not overlap any other. The run ends with `<passed>/<total> passed` and exits non-zero on any failure.

See [`docs/testing.md`](docs/testing.md) for the spec format, the full step vocabulary, the element registry contract, and the mandatory process rules (for example, any edit to a pre-existing test is flagged as a potential regression).

## Web build

```bash
npm install
bash scripts/build_web.sh   # outputs to web/
```

`APP_TITLE` env var overrides the browser tab title (default: `"Love Exemplar"`).

## CI / Cloudflare Pages

Two GitHub Actions workflows are included:

- **`ci.yml`** — runs `love . --headless` on every push and PR
- **`web.yml`** — builds the web output and deploys to Cloudflare Pages

To activate the web deploy, see [`docs/setup-cloudflare.md`](docs/setup-cloudflare.md). In short, set these in your GitHub repository settings:

| Type | Name | Value |
|------|------|-------|
| Secret | `CLOUDFLARE_API_TOKEN` | your Cloudflare API token |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | your Cloudflare account ID |
| Variable | `CLOUDFLARE_PROJECT_NAME` | your Cloudflare Pages project name |
| Variable | `APP_TITLE` | browser tab title (optional) |

PR previews are deployed automatically and linked in a PR comment. Production deploys on push to `master`.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Headless tests** — there is no third-party framework. `lua/headless/stubs.lua` installs no-op love API replacements so tests run without a window. `runner.lua` runs the unit tests (plain `assert` scripts, optionally scripted with `HeadlessInput`), then `ui_runner.lua` plays the UI specs through real input. Neither covers real rendering, saves or the web build. See [`docs/testing.md`](docs/testing.md).
