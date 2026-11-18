# Matrix Circuit

A SpaceChem-style puzzle game built in Love2D. Program a 2D circuit grid to transform an input matrix into a target matrix using elementary matrix operations.

## How to play

The play area is a **10×10 grid** with a **Source** (green) and **Sink** (blue) cell fixed by each puzzle. The matrix starts on the Source and does not move on its own — you place **pushers** and program them on a shared **timeline**. Pushers walk around the board and shove the matrix when they walk into it. Op tiles in its path transform it; any matrix cell touching the Sink ends the run.

**Controls:**

| Key | Action |
|-----|--------|
| `R` | Run — one timeline tick at a time, animated |
| `Space` | Step — advance one tick |
| `Backspace` | Reset — return the matrix to the source |
| `← →` | Previous / next puzzle |
| Left-click grid | Place selected tile |
| Right-click grid | Erase tile |
| Left-click palette | Select a tile type |
| Left / right-click timeline slot | Cycle that slot's command forward / back |
| `Esc` | Quit |

**Tile types:**

- **P** (Pusher) — a 1×1 mobile unit labelled A–H (up to 8). The tile you place is its start cell. Each tick its timeline command (`^ v < >`, or `.` idle) moves it one cell. Walking into a matrix cell shoves the whole matrix one cell the same way (a pusher starting under the matrix rides along inside it). Pushers stay put at the grid edge and gap cells, and can't walk into each other; a shove that would push the matrix off the grid, onto a gap, or onto another pusher does nothing. Pushers act in letter order each tick, so A moves before B.
- **×** (Gap) — dark impassable cells placed by the puzzle. Neither pushers nor any part of the matrix can enter them. Some puzzles require reshaping the matrix (e.g. transposing a 2×3 into a 3×2) to fit through a narrow gap corridor.
- **×R** (Scale Row) — vertical tile spanning the matrix's row count; click a band to select the target row, then click left/right thirds of the selected band to adjust the scalar
- **⇅R** (Swap Rows) — 1×2 vertical tile; click left/right thirds of each strip to adjust the row index
- **−I** (Negate) — multiply every element by −1
- **×k** (Scalar Mul) — multiply every element by a scalar
- **+M** (Add Matrix) — element-wise add a constant matrix; expands up to 4×4 via `+`/`−` affordances on the tile edges
- **−M** (Sub Matrix) — element-wise subtract a constant matrix; same resizable grid layout
- **×M** (Mul Matrix) — element-wise multiply by a constant matrix; same resizable grid layout
- **=R** (Set Row) — replace a row with user-defined values; left cell selects the row, additional cells hold the values (expandable up to 4 columns)

Click a value cell on any matrix op tile to increment/decrement its value (left/right thirds = −1/+1). Values are clamped to [−9, 9].

Each puzzle only offers the op tiles it needs in the palette (the pusher and eraser are always there).

Op tiles span one board cell for the op plus one per parameter. Click the left third of a parameter cell for −1 and the right third for +1. An op fires once when the matrix first overlaps any of its cells, and re-arms after the matrix fully leaves.

**Timeline:** the panel in the right column has one row per pusher and `len` slots (default 8, adjustable 1–16, loops). Edit it while stopped. Every pusher runs the same loop, so offset the commands to choreograph them.

**Winning:** when any matrix cell touches the Sink and the transformed matrix equals the target, you win. A run with no movement for a full timeline loop ends as **STUCK**, and a run past 500 ticks ends as **TIMEOUT**.

**16 puzzles** — from a simple identity check (puzzle 1) through increasingly complex matrix transformations. Puzzles 1–11 each introduce or practice a single operation; puzzles 12–16 require two or three different operations in sequence (e.g. transpose then scale, Gaussian elimination, or a three-step chain). Puzzles can use non-square (n×m) matrices.

## Structure

```
core/lua/       Engine classes — no game knowledge (Camera, Drawer, Input, Scene,
                SceneManager, Sprite, SpriteSet, Timer, Fonts)
game/           Game-specific code (Player, GameScene)
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets
conf.lua        Window config; suppresses graphics/audio modules under --headless
main.lua        Entry point — canvas rendering with letterboxing, pixel-art filter
```

See [`core/lua/README.md`](core/lua/README.md) for API docs on each engine class.

## Running

```bash
love .                  # normal window
love . --headless       # run tests and exit
```

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
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame. See `tests/test_basics.lua` for a minimal example.
