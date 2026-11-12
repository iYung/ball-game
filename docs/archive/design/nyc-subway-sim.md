# NYC Subway Sandbox Simulation

## Goal

Build a Love2D sandbox simulation of the NYC subway system driven by real MTA data. Players watch trains move along actual routes, see stations accumulate passengers based on historical ridership, and can toggle subway lines on/off to observe how the network degrades — stations pile up, service gaps emerge.

No win condition. Pure exploration.

---

## Affected files

New files (all new — the existing ball-game scene is replaced or sits alongside):

```
data/
  stations.json          — parsed MTA station lat/lon + line memberships
  routes.json            — GTFS routes (line id, name, color)
  trips.json             — GTFS trips → stop_times (schedule)
  ridership.json         — hourly ridership per station from turnstile data
game/scenes/
  subway_scene.lua       — main scene (replaces game_scene.lua)
game/subway/
  network.lua            — station + edge graph, owns the lines table (MTA + custom)
  train.lua              — single train entity (position, route, passengers)
  train_scheduler.lua    — spawns trains per GTFS schedule + custom lines, advances sim clock
  station.lua            — station entity (crowd counter, draw)
  passenger_flow.lua     — feeds ridership data into station crowd counts
  line_editor.lua        — UI: sidebar list + draw-mode for adding/deleting lines
  map.lua                — lat/lon → screen coords, background map rendering
scripts/
  fetch_data.sh          — downloads GTFS zip + turnstile CSV
  parse_gtfs.lua         — converts GTFS text files → data/trips.json etc.
  parse_ridership.lua    — converts MTA turnstile CSV → data/ridership.json
```

The existing `game/player.lua`, `game/scenes/game_scene.lua` are not deleted but are no longer the entry point.

---

## What changes

### Data pipeline (offline, run once)

1. `scripts/fetch_data.sh` downloads:
   - MTA GTFS static zip: `https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip`
   - MTA turnstile/ridership data from data.ny.gov (CSV, ~2 years)

2. `scripts/parse_gtfs.lua` reads the GTFS text files and emits:
   - `data/stations.json`: `{id, name, lat, lon, lines[]}`
   - `data/routes.json`: `{id, short_name, color}`
   - `data/trips.json`: per-route list of trips, each with ordered stop+arrival_time pairs

3. `scripts/parse_ridership.lua` reads turnstile CSV and emits:
   - `data/ridership.json`: `{station_id → {day_of_week → {hour → avg_entries}}}` — 7 day profiles × 24 hours, averaged across the last 2 years. `day_of_week` is 1–7 (Mon–Sun).

### Rendering: `game/subway/map.lua`

Converts WGS-84 lat/lon to screen pixels using a simple Mercator projection clamped to NYC's bounding box (roughly 40.49°N–40.92°N, -74.26°W–-73.70°W) mapped to the 1280×720 canvas.

Draws two background layers:
1. NYC borough outline polygons (dim gray, from NYC Open Data GeoJSON converted to a Lua table) — just Manhattan for now.
2. Subway line polylines in MTA brand colors connecting station positions.

Pan: left-click drag moves `camera.x/y`. Zoom: scroll wheel adjusts `camera.zoom` (clamped 0.5×–4×). The subway scene owns these inputs directly (not using the base Camera's `follow` logic).

### Simulation clock: `game/subway/train_scheduler.lua`

Runs a compressed sim clock. Default: 1 real second = 1 sim minute (60× speed). Adjustable with +/- keys.

At each clock tick:
- Spawns trains whose departure time just passed.
- Advances active trains along their stop sequence, interpolating position between stops.
- Delivers passengers: when a train arrives at a stop, it removes crowd from the station (capped by train capacity, 1000 per car × 8 cars = 8000 max per train).

### Train entity: `game/subway/train.lua`

Fields: `route_id`, `trip_id`, `stop_sequence[]`, `current_leg` (index), `progress` (0–1 along leg), `x`, `y`, `active`.

Drawn as a small colored dot (line color) moving smoothly between stations.

### Station entity: `game/subway/station.lua`

Fields: `id`, `name`, `x`, `y`, `lines[]`, `crowd` (integer).

Each sim minute, adds `ridership[station_id][sim_day_of_week][sim_hour]` passengers to `crowd` (spread as `hourly_entries / 60` per minute). The UI shows current sim day + time.

Drawn as a circle whose radius grows with `crowd` — small dot at 0, large pulsing circle when overflowing. Color shifts green → yellow → red as crowd grows.

### Line editor: `game/subway/line_editor.lua`

The sidebar has two modes, toggled with a button:

**View mode (default):**
A scrollable list of all lines (MTA originals + custom) with their colors and an on/off toggle. Toggling a line off:
- In-flight trains on that line finish their current leg then disappear.
- No new trains spawn on that line.
- Affected stations accumulate crowd undraned.

A **Delete** (×) button beside each line permanently removes it and its trains from the simulation. MTA lines can be deleted too.

**Draw mode (activated by "New Line" button):**
1. User clicks a color swatch to pick a color (8 preset options).
2. User clicks existing station dots on the map in sequence to build a stop list. Each click snaps to the nearest station within 20px screen distance.
3. A preview polyline follows the cursor showing the line-in-progress.
4. Press Enter or click "Done" to confirm. The new line is added with a generated name ("Custom 1", "Custom 2", …).
5. Press Escape to cancel.

After confirming a custom line's stops, the user sets a **train count** (1–20, default 4) via a +/− control in the sidebar. The scheduler derives headway as `line_round_trip_time / num_trains` and distributes trains evenly across the line in both directions. The train count can be adjusted at any time from the sidebar — increasing it spawns new trains immediately; decreasing it removes the last train in each direction after it completes its current leg.

MTA lines keep their GTFS-driven schedules (exact train counts are implicit in the timetable). Train capacity and boarding rate are the same for all lines.

**Network data model** (`game/subway/network.lua`):
```lua
network.lines = {
  [line_id] = {
    id, name, color,          -- {r,g,b}
    stops = { station_id, … }, -- ordered
    active = true,
    is_custom = false,
  }
}
```
MTA lines are populated from `data/routes.json` + `data/trips.json` at load. Custom lines are appended at runtime (not persisted between sessions).

Stations on multiple lines still get service from all active lines they belong to.

### Passenger flow: `game/subway/passenger_flow.lua`

Each update:
```
station.crowd += ridership[station.id][sim_hour] * dt_minutes
if train arrives at station:
    station.crowd = max(0, station.crowd - train_capacity * boarding_rate)
```

`boarding_rate` is a constant (default 0.7 — trains don't fill 100% at every stop).

---

## What stays the same

- `main.lua` — only the initial scene switches from `GameScene` to `SubwayScene`.
- `conf.lua` — unchanged, 1280×720 resizable window.
- All `lua/core/` modules: `camera`, `drawer`, `timer`, `scene`, `scene_manager`, `sprite`, etc. The subway scene extends `Scene` the same way `GameScene` does.
- `lua/headless/` — test runner unchanged.
- CI/web workflows — unchanged.
- Existing tests — unchanged.

---

## Resolved decisions

1. **Ridership patterns** — Day-of-week aware: separate average profiles for Monday–Sunday. The parse script buckets turnstile entries by `(station_id, day_of_week, hour)`.

2. **Map background** — Both: NYC borough outline polygons as a dim background layer, plus colored subway line polylines on top.

3. **Starting sim time** — Midnight (00:00). The day builds from silence to rush hour naturally.

4. **Camera controls** — Pan (click + drag) and zoom (scroll wheel). The subway scene owns its own camera state separate from the base Camera module's follow logic.

5. **Scope** — Manhattan only (~150 stations). The most line-dense borough, best legibility at 1280×720, straightforward to extend later.

---

## Data sources

| Data | Source | Format | Notes |
|---|---|---|---|
| Station locations | GTFS `stops.txt` | CSV in zip | lat/lon per stop |
| Routes + colors | GTFS `routes.txt` | CSV in zip | official line colors |
| Train schedules | GTFS `stop_times.txt` | CSV in zip | ~500k rows |
| Hourly ridership | data.ny.gov MTA turnstile | CSV | ~2 years available |

GTFS zip: `https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip` (free, no key required)
Turnstile data: `https://data.ny.gov/resource/wujg-7c2s.csv` (Socrata API, free, no key for small pulls)
