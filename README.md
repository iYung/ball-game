# Matrix Circuit

A SpaceChem-style puzzle game built in Love2D. Program a 2D circuit grid to transform an input matrix into a target matrix using elementary matrix operations. Choose from 21 puzzles, grouped into five worlds, on the level-select screen; completing a puzzle shows a solution recap screen then proceeds to the next puzzle.

## How to play

The play area is a **10×10 grid** with a **Source** (green) and **Sink** (blue) fixed by each puzzle. The Source tile spans the same number of cells as the input matrix (rows × cols), showing exactly where the matrix will sit at the start of a run. The matrix does not move on its own — you place **pushers** and program them on the **timeline** along the bottom of the screen. Pushers walk around the board and shove the matrix when they walk into it. Op tiles in its path transform it; any matrix cell touching the Sink ends the run.

**Level select:**

| Key | Action |
|-----|--------|
| `Left / Right` | Switch world |
| `Up / Down` | Navigate puzzle list within world |
| `Enter` | Play selected puzzle |
| `Esc` | Open settings |
| Click a row | Play that puzzle |

Puzzles are grouped into five worlds — **Basics** (1–5), **Combos** (6–11), **Advanced** (12–15), **Transforms** (16–18), and **Fixed Pieces** (19–21) — shown as tabs in a top bar. Click a tab or press Left/Right to switch worlds. World 1 is always open; every later world is **locked** until all puzzles in the previous world are solved, and locked worlds are skipped when cycling. Click a puzzle row to play it. Hovering highlights a row only when the mouse actually moves, so a resting cursor never overrides Up/Down navigation. On the start screen, press `D` or click **(D) Unlock All** to mark every puzzle solved (useful for testing or jumping ahead).

**In-game controls:**

| Key / Button | Action |
|-------------|--------|
| `R` or **Run** button | Run — one timeline tick at a time, animated (not available while running or after a win). The matrix slides into an op tile with its old values; the result shows once it has arrived, exactly as in the solution recap |
| `Backspace` or **Reset** button | Reset — return the matrix to the source (no-op when there is nothing to reset) |
| `Esc` or **Menu** button | Open settings overlay (SFX / music volume, Resume, Exit to Menu) |
| Left-click grid | Place selected tile, edit a placed op tile (see below), erase with **[X]**, or pick up a tile in **[Mv]** mode |
| Right-click grid | Erase tile (or cancel an in-progress drag) |
| Left-click or drag an op from the left column | Select a tile type; drag it onto a grid cell to place it |
| Click `^` / `v` in the left column | Scroll the ops column one row (only shown when it doesn't fit) |
| Drag an instruction chip (`^ v < > .`) onto a timeline slot | Write that command for the selected pusher (click the chip, then a slot, also works). Dragging a filled slot moves it; dragging it off the bar or right-clicking removes it |
| Click `A`, `B`, ... above the chips | Choose which placed pusher the chips program |
| Click `<` / `>` on the timeline | Scroll the visible ticks (the timeline is 60 ticks long, 4 lanes) |

The **left column** holds the op tiles (drag them onto the grid). The **bottom bar** holds the instruction chips and pusher selector on the left, the 4-lane **timeline** in the middle, and **Run**, **Reset**, **Menu** and (after a win) **Continue** on the right. Buttons that aren't applicable in the current state are shown dimmed, and the keyboard shortcuts follow the same rules as the buttons. The current puzzle number (`Puzzle N/21`) is shown at the top-left of the right-hand panel.

**Tile types:**

- **P** (Pusher) — a 1×1 mobile unit labelled A–H (up to 8). The tile you place is its start cell. A timeline command (`^ v < >`) sets its direction and it keeps walking that way, one cell per tick, until another command changes it; `.` (stop) halts it. Walking into a matrix cell shoves the whole matrix one cell the same way (a pusher starting under the matrix rides along inside it). Any moving pusher whose step cannot be executed — hitting the grid edge, a gap, another pusher, or trying to shove the matrix when it has nowhere to go — immediately ends the run as **FAIL**. If a transform (e.g. transpose) produces a footprint that extends off the grid, overlaps a gap, or overlaps a pusher, the run also ends as **FAIL**. A stopped pusher never causes a fail. Pushers act in letter order each tick, so A moves before B.
- **×** (Gap) — dark impassable cells placed by the puzzle. Neither pushers nor any part of the matrix can enter them. Some puzzles require reshaping the matrix (e.g. transposing a 2×3 into a 3×2) to fit through a narrow gap corridor.

**Op tiles** are all one cell and have at most one number, *k*. An op acts either on the **whole matrix** or on **one edge** of it. The palette label is on the left; a placed tile shows its operation and value (`x2`, `+1`, `-3`).

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

An op fires once when the matrix first covers its cell, and re-arms after the matrix leaves it.

Each puzzle only offers the op tiles it needs in the palette (the pusher, **[Mv]** move tool, and eraser are always there).

**Moving tiles:** select **[Mv]** in the palette, then click any unlocked tile to pick it up. A ghost preview follows the cursor — green means the drop is valid, red means the target is occupied or out of bounds. Release the mouse to drop, or right-click to cancel (the tile snaps back to its original position). A moved op tile keeps its *k* and edge.

**Fixed and locked ops:** some puzzles offer fixed ops, labelled with a `!` suffix in the palette (e.g. `x-1!`, `FLv!`; a fixed edge op also shows its arrow). Their value and edge are preset: they can be placed, moved and erased but not edited, and are marked `=`. Locked tiles (lock icon) are pre-positioned by the puzzle and cannot be moved, erased, or edited.

**Timeline:** 4 lanes by 60 ticks along the bottom bar, so up to 4 commands can happen on one tick. Each command is stamped with the pusher it targets (pick it with the `A`/`B`/... selector before dragging a chip). A pusher that already has a command on a tick gets it replaced. The timeline does not loop: after the last command every pusher keeps its direction. Edit it while stopped; use `<` / `>` to scroll, and during a run the view follows the current tick.

**Winning:** when any matrix cell touches the Sink and the transformed matrix equals the target, you win. Click the **Continue** button (or press `Enter`) to open the **solution recap screen**, which shows the number of ticks your solution took, the number of pieces you placed, and a looping animated playback of your solution — matrix ball and pushers moving in sync — on the board. Click the **Next puzzle**, **Replay**, or **Menu** button (or press `Enter`, `R`, or `Esc`) to advance to the next puzzle, replay the animation, or return to the level-select screen. Clicks outside the three buttons do nothing. A run in which nothing moves after the last command ends as **STUCK**.

**21 puzzles** — a simple identity check (puzzle 1), then single ops and short routes in **Basics** and **Combos** (several of which chain two ops), two- and three-op chains with edge ops in **Advanced**, column edits, flips and a rotation in **Transforms**, and fixed tools and locked tiles in **Fixed Pieces** (puzzle 19 offers only its fixed `!` ops, no editable ones). Puzzles can use non-square (n×m) matrices.

Saved progress from the earlier 23-puzzle numbering is converted to the new numbering when it is loaded.

## Puzzle editor

A built-in puzzle editor is accessible from the title screen — press **E** or click **(E) Editor**.

The editor has the same 10×10 grid as the game and a bottom palette with **SRC** (Source), **SNK** (Sink), **GAP**, the pusher **P**, all ten op tiles and the eraser **[X]**. Up to 8 pushers can be placed; each gets the lowest free letter (A–H), which is saved with the puzzle. Every tile you place is exported as locked, but stays editable inside the editor: click the thirds of an op tile to change *k* or turn its edge, as in the game. Erase with **[X]** or a right-click. The right-hand HUD lets you:

- Set the **puzzle name** (click the name field to type)
- Edit the **INPUT** and **TARGET** matrices (rows/cols spinners and click-to-edit value cells)
- Choose which ops the player can freely use (**op allowlist** toggles; with none or all selected, every op is offered)

The editor does not support fixed palette ops (`fixed_ops`).

**Copy** serialises the current puzzle to a Lua string and copies it to the clipboard in the same format as `data/puzzles/*.lua`. **Paste** reads from the clipboard and loads a previously copied puzzle back into the editor. A definition that names an unsupported op or has an invalid *k* or edge is rejected with a message, and unreadable text shows `Parse error`; the editor is left unchanged. **Test** opens the puzzle directly in the game for play-testing; pressing Menu there returns to the editor. **Back** returns to the title screen.

To add a custom puzzle to the game, copy the Lua source into a new file under `data/puzzles/` and register it in `lua/game/puzzle_loader.lua`.

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
