# Matrix Circuit

A SpaceChem-style puzzle game built in Love2D. Program a 2D circuit grid to transform an input matrix into a target matrix using elementary matrix operations.

## How to play

The play area is a **10×10 grid** with a **Source** (green) and **Sink** (blue) cell fixed by each puzzle. Place tiles on the grid to route a cursor from Source to Sink — the cursor carries the matrix and applies operations as it passes through op tiles.

**Controls:**

| Key | Action |
|-----|--------|
| `R` | Run — animate the cursor at full speed |
| `Space` | Step — advance the cursor one cell |
| `Backspace` | Reset — return cursor to source |
| `← →` | Previous / next puzzle |
| Left-click grid | Place selected tile |
| Right-click grid | Erase tile |
| Left-click palette | Select a tile type |
| `Esc` | Quit |

**Tile types:**

- **Arrows** (`→ ← ↑ ↓`) — redirect the cursor
- **T** (Transpose) — swap rows and columns
- **×R** (Scale Row) — multiply one row by a scalar
- **R+R** (Add Rows) — add a multiple of one row to another
- **↔R** (Swap Rows) — exchange two rows
- **−I** (Negate) — multiply every element by −1
- **×k** (Scalar Mul) — multiply every element by a scalar

Op tiles that need parameters (row indices, scalars) open a small editor when you click to place them. Tab cycles fields, Enter confirms, Esc cancels.

**Winning:** when the cursor reaches the Sink and the transformed matrix matches the target, you win. If the cursor loops or leaves the grid, the run fails.

**10 puzzles** — from a simple straight-wire tutorial (puzzle 1) through 3×3 Gaussian elimination (puzzle 10).

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
