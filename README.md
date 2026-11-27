# Matrix Circuit

A SpaceChem-style puzzle game built in Love2D. Program a 2D circuit grid to transform an input matrix into a target matrix using elementary matrix operations. Choose from 26 puzzles, grouped into six worlds, on the level-select screen; completing a puzzle shows a solution recap screen then proceeds to the next puzzle.

## How to play

The play area is a **10×10 grid** with a **Source** (green) and **Sink** (blue) fixed by each puzzle. The Source tile spans the same number of cells as the input matrix (rows × cols), showing exactly where the matrix will sit at the start of a run. The matrix does not move on its own — you place **pushers** and program them on the **timeline** along the bottom of the screen. Pushers walk around the board and shove the matrix when they walk into it. Op tiles in its path transform it; any matrix cell touching the Sink ends the run. Some puzzles have a [second source](#two-sources-and-matrix-ops), so two matrices travel the board and are merged by a matrix op.

**Level select:**

| Key | Action |
|-----|--------|
| `Left / Right` | Switch world |
| `Up / Down` | Navigate puzzle list within world |
| `Enter` | Play selected puzzle |
| `Esc` | Open settings |
| Click a row | Play that puzzle |

The shipped puzzles are grouped into six worlds (**Basics**, **Combos**, **Advanced**, **Transforms**, **Fixed Pieces** and **Two Sources**), shown as tabs in a top bar. Click a tab or press Left/Right to switch worlds. A world is open if it is the first one, if every puzzle in all earlier worlds is solved, or if any puzzle in it or in a later world is solved, so a level added to an early world does not lock you out of where you have been. One limit: a world you had opened but solved nothing in (and nothing after it) locks again until the new level is solved. Locked worlds are skipped when cycling. Click a puzzle row to play it. Hovering highlights a row only when the mouse actually moves, so a resting cursor never overrides Up/Down navigation. On the start screen, press `D` or click **(D) Unlock All** to mark every puzzle solved (useful for testing or jumping ahead).

**In-game controls:**

| Key / Button | Action |
|-------------|--------|
| `R` or **Run** button | Run — one timeline tick at a time, animated (not available while running or after a win). The matrix slides into an op tile with its old values; the result shows once it has arrived, exactly as in the solution recap |
| `Backspace` or **Reset** button | Reset — return each matrix to its source (no-op when there is nothing to reset). A tile being moved with **[Mv]** goes back where it was |
| `T` | Turn a two-cell matrix op: the tile being dragged, else the editable one under the cursor, else the selected **M+** / **Mx** tool |
| `Esc` or **Menu** button | Open settings overlay (SFX / music volume, Resume, Exit to Menu) |
| Left-click grid | Place selected tile, edit a placed op tile (see below), erase with **[X]**, or pick up a tile in **[Mv]** mode |
| Right-click grid | Erase tile (or cancel an in-progress drag) |
| Left-click or drag an op from the left column | Select a tile type; drag it onto a grid cell to place it |
| Click `^` / `v` in the left column | Scroll the ops column one row (only shown when it doesn't fit) |
| Drag an instruction chip (`^ v < > .`) onto a timeline slot | Write that command for the selected pusher (click the chip, then a slot, also works). Dragging a filled slot moves it; dragging it off the bar or right-clicking removes it |
| Click `A`, `B`, ... above the chips | Choose which placed pusher the chips program |
| Click `<` / `>` on the timeline | Scroll the visible ticks (the timeline is 60 ticks long, 4 lanes) |

The **left column** holds the op tiles (drag them onto the grid). The **bottom bar** holds the instruction chips and pusher selector on the left, the 4-lane **timeline** in the middle, and **Run**, **Reset**, **Menu** and (after a win) **Continue** on the right. Buttons that aren't applicable in the current state are shown dimmed, and the keyboard shortcuts follow the same rules as the buttons. The current puzzle number (`Puzzle N/total`) is shown at the top-left of the right-hand panel.

**Tile types:**

- **P** (Pusher) — a 1×1 mobile unit labelled A–H (up to 8). The tile you place is its start cell. A timeline command (`^ v < >`) sets its direction and it keeps walking that way, one cell per tick, until another command changes it; `.` (stop) halts it. Walking into a matrix cell shoves the whole matrix one cell the same way (a pusher starting under the matrix rides along inside it). Any moving pusher whose step cannot be executed — hitting the grid edge, a gap, another pusher, or trying to shove the matrix when it has nowhere to go — immediately ends the run as **FAIL**. If a transform (e.g. transpose) produces a footprint that extends off the grid, overlaps a gap, or overlaps a pusher, the run also ends as **FAIL**. A stopped pusher never causes a fail. Pushers act in letter order each tick, so A moves before B.
- **×** (Gap) — dark impassable cells placed by the puzzle. Neither pushers nor any part of the matrix can enter them. Some puzzles require reshaping the matrix (e.g. transposing a 2×3 into a 3×2) to fit through a narrow gap corridor.

**Op tiles** have at most one number, *k*, and all are one cell except the two [matrix ops](#two-sources-and-matrix-ops). A one-cell op acts either on the **whole matrix** or on **one edge** of it. The palette label is on the left; a placed tile shows its operation and value (`x2`, `+1`, `-3`).

| Palette | Op | Acts on | *k* (default) |
|---------|----|---------|---------------|
| `xk` | Scale: multiply by *k* | whole matrix | −9 to 9 (2) |
| `xk^` | Scale | one edge | −9 to 9 (2) |
| `+k` | Add *k* | whole matrix | 0 to 9 (1) |
| `+k^` | Add | one edge | 0 to 9 (1) |
| `-k` | Subtract *k* | whole matrix | 0 to 9 (1) |
| `-k^` | Subtract | one edge | 0 to 9 (1) |
| `T` | Transpose | whole matrix | — |
| `R90` | Rotate 90° clockwise (swaps the dimensions) | whole matrix | — |
| `FLh` | Flip left-right (reverse the columns) | whole matrix | — |
| `FLv` | Flip up-down (reverse the rows) | whole matrix | — |

An **edge** is the top row, right column, bottom row or left column of the matrix as it is when the tile fires. A new edge tile targets the top; its arrow (`^ > v <`) and a solid bar show the targeted side. Only *k* is limited: results may be negative or larger than 9. Scaling by −1 negates.

**Editing a placed tile:** click the left third for *k* − 1 and the right third for *k* + 1 (it stops at the limits). Click the middle third of an edge tile to turn it clockwise (top, right, bottom, left); the middle does nothing on other tiles. With **[X]** selected, a click on any third erases the tile.

A one-cell op fires once when a matrix first covers its cell, and re-arms after that matrix leaves it. With two matrices each one fires and re-arms tiles independently.

Each puzzle only offers the op tiles it needs in the palette (the pusher, **[Mv]** move tool, and eraser are always there). A puzzle with no `ops` list offers the ten ops above; **M+** and **Mx** appear only when a puzzle lists them.

### Two sources and matrix ops

Some puzzles have two sources, **SRC 1** and **SRC 2**, each with its own input matrix (shown as **INPUT 1** and **INPUT 2** in the side panel, with different border colours on the board; before a run each source's preview is also tagged with its name). Pushers shove either matrix. There is still only one Sink.

| Palette | Op | Valid when | Result |
|---------|----|------------|--------|
| `M+` | Matrix add | L and R have the same shape | L + R, cell by cell |
| `Mx` | Matrix multiply | columns of L = rows of R | matrix product L x R |

- A matrix op is one tile over two adjacent cells: a left-operand cell **L** and a right-operand cell **R**. The names refer to the operand, not a screen side, so R may sit right of, below, left of or above L. A matrix covering one of the cells shows a small L or R badge, in the game and in the solution recap.
- It fires once each cell is covered by a different matrix, in either order of arrival. A single waiting matrix does nothing. The result appears at the left matrix's top-left position and the right matrix is consumed. If the result does not fit there, the run fails as blocked.
- A matrix op the result covers stays inactive until the result has left both of its cells.
- Both matrices move at the same time and never push each other. One may move into cells the other leaves on the same tick, and they may touch.
- The run fails with a red banner if the matrices overlap, swap places or clip each other diagonally (**matrices collided**), if one matrix covers both cells of a matrix op (**one matrix on both inputs**, even when only passing over), if the shapes do not fit (e.g. **can't multiply 2x3 by 2x2**), or if a matrix reaches the Sink while there are still two (**matrices not combined**).
- **Placing and turning:** the L cell goes where you click or drop, and both cells must be empty. The button's arrow (`> v < ^`) points from L to R; click the selected button again, or press `T`, to turn the tool. Click either cell of a placed editable tile, or press `T` over it, to turn it clockwise around L, skipping sides that are off the grid or occupied. Dragging a palette tool onto it does nothing, except the eraser. Erasing either cell removes the whole tile. **[Mv]** moves it whole, keeping its orientation, and the cell you grabbed stays under the cursor. Fixed (`!`) matrix ops can be placed, moved and erased but not turned.

**Moving tiles:** select **[Mv]** in the palette, then click any unlocked tile to pick it up. A ghost preview follows the cursor — green means the drop is valid, red means the target is occupied or out of bounds. Release the mouse to drop, or right-click to cancel (the tile snaps back to its original position). A moved op tile keeps its *k*, edge or orientation.

**Fixed and locked ops:** some puzzles offer fixed ops, labelled with a `!` suffix in the palette (e.g. `x-1!`, `FLv!`; a fixed edge op also shows its arrow). Their value and edge are preset: they can be placed, moved and erased but not edited, and are marked `=`. Locked tiles (lock icon) are pre-positioned by the puzzle and cannot be moved, erased, or edited.

**Timeline:** 4 lanes by 60 ticks along the bottom bar, so up to 4 commands can happen on one tick. Each command is stamped with the pusher it targets (pick it with the `A`/`B`/... selector before dragging a chip). A pusher that already has a command on a tick gets it replaced. The timeline does not loop: after the last command every pusher keeps its direction. Edit it while stopped; use `<` / `>` to scroll, and during a run the view follows the current tick.

**Winning:** when any matrix cell touches the Sink, only one matrix is left and it equals the target, you win. Click the **Continue** button (or press `Enter`) to open the **solution recap screen**, which shows the number of ticks your solution took, the number of pieces you placed, and a looping animated playback of your solution — matrices and pushers moving in sync (including any merge) — on the board. Click the **Next puzzle**, **Replay**, or **Menu** button (or press `Enter`, `R`, or `Esc`) to advance to the next puzzle, replay the animation, or return to the level-select screen. Clicks outside the three buttons do nothing. A run in which nothing moves after the last command ends as **STUCK**.

**26 puzzles** ship with the game: a simple identity check (puzzle 1), then single ops and short routes in **Basics** and **Combos** (several of which chain two ops), two- and three-op chains with edge ops in **Advanced**, column edits, flips and a rotation in **Transforms**, fixed tools and locked tiles in **Fixed Pieces** (puzzle 19 offers only its fixed `!` ops, no editable ones; the last, **Rotato**, bounces the matrix across a locked tile and your own rotation), and matrix add and multiply with two sources in **Two Sources**. Puzzles can use non-square (n×m) matrices.

Progress is saved by puzzle and world id (the file or folder name without its number prefix), so inserting or renumbering levels keeps solved marks. Saves from older versions, including the earlier 23-puzzle numbering, are converted when loaded and rewritten in the new format the next time progress changes. A game version from before this format shows such a save as empty and overwrites it the next time progress changes.

## Puzzle editor

A built-in puzzle editor is accessible from the title screen — press **E** or click **(E) Editor**.

The editor has the same 10×10 grid as the game and a bottom palette with **SRC** (Source), **SRC2** (second source), **SNK** (Sink), **GAP**, the pusher **P**, all twelve op tiles and **Erase**; **Back**, **Test**, **Copy** and **Paste** sit at the right end of the palette. Every tile you place is exported as locked, but stays editable inside the editor: click the thirds of an op tile to change *k* or turn its edge, as in the game. Select **Erase** and click a tile to remove it (any cell of a source or matrix op works), or right-click it. **M+** and **Mx** are turned as in the game: click either cell of a placed tile, click the selected palette button again, or press `T` (not while typing the name). The puzzle has two sources only while **SRC2** is on the grid; if **SRC2** is placed without **SRC**, **Copy** and **Test** put Source 1 on a spot that does not overlap it. Placing a tool, including the Sink, never replaces an occupied cell. Up to 8 pushers can be placed; each gets the lowest free letter (A–H), which is saved with the puzzle. The right-hand HUD lets you:

- Set the **puzzle name** (click the name field to type)
- Edit the **INPUT 1**, **INPUT 2** (switch with **#1** / **#2**) and **TARGET** matrices (rows/cols spinners and click-to-edit value cells). A source that no longer fits after a resize is removed
- Choose which ops the player can freely use (**op allowlist** toggles; with nothing selected, or exactly the ten one-cell ops, those ten are offered; **M+** / **Mx** are offered only when toggled on. After pasting a puzzle with `ops = {}`, none are offered until a toggle is clicked)

The editor has no controls for fixed palette ops (`fixed_ops`) and does not display them, but it keeps a pasted list, and an empty `ops = {}`, through **Paste**, **Test** and **Copy**. The list stays until you paste another puzzle or leave the editor for the title screen.

**Copy** serialises the current puzzle to a Lua string and copies it to the clipboard in the puzzle file format. **Paste** reads from the clipboard and loads a previously copied puzzle back into the editor. The text is read as data and never run: only plain table literals (strings, numbers, booleans, nested tables, comments) are accepted. A definition that names an unsupported op, has an invalid *k*, edge or facing, has only one of `source2` / `input2`, or has a malformed second source is rejected with a message, and unreadable text shows `Parse error`; the editor is left unchanged. **Test** opens the puzzle directly in the game for play-testing. After a win, **WIN!** stays on screen and **Continue** (or `Enter`) returns to the editor with the draft kept: the solution recap is not shown and no progress is recorded. The **Menu** button and **Exit to Menu** in the settings overlay (`Esc`) also return to the editor, where the menu music resumes. Your volume settings carry through the editor and Test. **Back** returns to the title screen.

## Adding levels

Worlds and puzzles come from the folder layout. No list needs editing.

```
data/puzzles/
  01_basics/
    01_identity.lua
    02_flip.lua
  02_combos/
    cutscene.lua        optional
    06_row_swap.lua
```

1. In the editor, set the puzzle name, build the level, check it with **Test**, then click **Copy**.
2. Create `data/puzzles/<NN>_<world>/<NN>_<id>.lua` and paste the text into it unchanged.
3. Restart the game (the web version needs a rebuild).

- Each folder in `data/puzzles/` with at least one puzzle is a world. Its tab name is the folder name without the number, with `_` as a space and each word capitalised (`05_fixed_pieces` is "Fixed Pieces"). A new world is just a new folder.
- Every `.lua` file in a world folder is a puzzle, except `cutscene.lua`. Other files are ignored. A puzzle placed directly in `data/puzzles/` is not shown, and a test fails on it.
- The `NN_` prefix sets the order, compared as a number; gaps are allowed. Equal numbers are ordered by name, and entries without a prefix come last, alphabetically. The level number shown in game is the position in the whole list, not the prefix.
- The id (`<id>` or `<world>`) must be unique among all puzzles or all worlds, even across folders; a duplicate stops the game with an error naming both paths.
- Moving or renumbering a puzzle keeps its solved mark; renaming its id resets it. Renaming a world folder's id makes its cutscene play again.
- A world's cutscene is `cutscene.lua` in its folder (same format as the shipped ones). It plays the first time the player switches to that world; the first world's never plays. The game intro is `data/cutscenes/world_0.lua`.
- A world fits at most **10 puzzles** on the level select screen (a test enforces this). World tabs share the screen width, so long names get tight beyond about 8 worlds.

A second source is the optional pair `source2 = { x, y }` and `input2 = { rows, cols, values }`. For `matrix_add` / `matrix_mul` tiles, `x, y` is the L cell and `params.facing` (`"right"` by default, `"bottom"`, `"left"`, `"top"`) is the side the R cell is on.

Run `love . --headless` after adding a level.

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

Unit tests print `PASS  tests/x.lua` / `FAIL  tests/x.lua — <error>`. UI specs drive the real scenes headlessly from the title screen (key presses, clicks on named buttons, cells, drags and timeline slots) and print `PASS  tests/ui/x.lua :: <name>` or the failing step and reason. On every frame the runner also checks each scene's UI element registry (`scene:ui_elements()`): every clickable element must be well-formed, on screen, and must not overlap any other. The run ends with `<passed>/<total> passed` and exits non-zero on any failure.

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
