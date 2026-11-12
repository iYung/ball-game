# love-exemplar

A minimal Love2D project demonstrating clean architecture patterns. Intended as a reference, not a game.

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

## NYC Subway Sandbox

The main scene is an interactive simulation of the New York City subway system using real MTA data.

### What it is

The sandbox renders the Manhattan subway network on a live map, runs trains on their actual GTFS schedules, models passenger crowds using real turnstile ridership data, and lets you draw and toggle custom lines.

### Data pipeline

Before launching the game, run the data pipeline once to populate `data/`:

```bash
# 1. Download GTFS schedule data and two years of turnstile ridership data
bash scripts/fetch_data.sh

# 2. Parse GTFS files into stations.json, routes.json, trips.json
luajit scripts/parse_gtfs.lua

# 3. Parse turnstile CSV into ridership.json (hourly averages per station)
luajit scripts/parse_ridership.lua
```

Pre-built data files are included in the repository so this step is optional unless you want fresh data.

### In-game controls

| Input | Action |
|-------|--------|
| Left-click drag | Pan the map |
| Scroll wheel | Zoom in / out |
| `+` / `-` keys | Increase / decrease simulation speed |
| `[+ New Line]` button | Enter draw mode — click stations to build a custom line |
| Enter / `[Done]` | Confirm a new custom line (need 2+ stops) |
| Escape / `[Cancel]` | Cancel line drawing |
| `[on]` / `[off]` toggle | Activate or deactivate any line |
| `[x]` button | Delete a custom line |
| `[−] N [+]` | Adjust train count on a custom line (1–20) |

The HUD in the top-left corner shows the current simulated day and time. Station circles grow and shift from green to red as crowds build; trains board passengers as they pass through.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame. See `tests/test_basics.lua` for a minimal example.
