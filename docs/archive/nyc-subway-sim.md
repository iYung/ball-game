# NYC Subway Sandbox Checklist

Tasks are ordered by dependency. Groups A–C can run in parallel within each group once the prior group is done.

---

## Group A — Data pipeline (run first, everything depends on this)

- [x] **A1** — `scripts/fetch_data.sh` — Write a bash script that:
  - Downloads `https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip` into `data/raw/gtfs/`
  - Unzips it in place
  - Downloads 2 years of MTA turnstile data from the Socrata API (`https://data.ny.gov/resource/wujg-7c2s.csv`) paginating with `$limit=50000&$offset=N` until exhausted, concatenating into `data/raw/turnstile.csv`
  - Prints progress lines for each step

- [x] **A2** — `scripts/parse_gtfs.lua` — Write a standalone Lua script (run with `lua scripts/parse_gtfs.lua`, not Love2D) that reads the unzipped GTFS files and writes three JSON files:
  - `data/stations.json`: array of `{id, name, lat, lon, lines}` — **Manhattan only** (filter: lat between 40.700 and 40.882, lon between -74.020 and -73.907); `lines` is a list of route short names serving that stop
  - `data/routes.json`: array of `{id, short_name, color_r, color_g, color_b}` — parse `route_color` hex from `routes.txt`; keep only routes that have at least one Manhattan stop
  - `data/trips.json`: object keyed by `route_id`, each value is an array of trips; each trip is `{trip_id, stops: [{station_id, arrival_seconds}]}` — `arrival_seconds` is seconds since midnight parsed from `stop_times.txt` HH:MM:SS; only include stops in Manhattan; only include trips that have ≥2 Manhattan stops
  - Depends on A1 (needs the unzipped GTFS files)

- [x] **A3** — `scripts/parse_ridership.lua` — Write a standalone Lua script that reads `data/raw/turnstile.csv` and writes `data/ridership.json`:
  - Schema: `{[station_id]: {[day_of_week]: {[hour]: avg_entries}}}` where `day_of_week` is 1–7 (Mon–Sun) and `hour` is 0–23
  - Match turnstile station names to `stations.json` ids via fuzzy name match (strip punctuation, uppercase, compare)
  - Average entries across all matching records for each `(station_id, day_of_week, hour)` bucket
  - Unmatched turnstile stations are silently skipped
  - Depends on A1 and A2

---

## Group B — Core game modules (independent of each other, depend on A)

- [x] **B1** — `game/subway/network.lua` — Write a Lua module that:
  - On `Network.load()`, reads `data/stations.json`, `data/routes.json`, `data/trips.json` using `love.filesystem.read` + a minimal JSON decoder (write a small `lua/util/json.lua` if none exists)
  - Exposes `network.stations` (table keyed by station id) and `network.lines` (table keyed by line id)
  - Each line entry: `{id, name, color={r,g,b}, stops={station_id,…}, active=true, is_custom=false, num_trains=nil}`
  - Provides `network:add_custom_line(stops, color, num_trains)` → returns new line id
  - Provides `network:remove_line(line_id)` → marks line deleted (sets `active=false`, flags `deleted=true`)
  - Provides `network:set_line_active(line_id, bool)`

- [x] **B2** — `game/subway/station.lua` — Write a Lua module for a single station entity:
  - `Station.new(data)` where `data` is a row from `network.stations`
  - Fields: `id`, `name`, `x`, `y` (screen coords, set externally), `lines`, `crowd=0`
  - `station:add_crowd(n)` — increments crowd
  - `station:board_train(capacity)` — reduces crowd by `capacity * 0.7`, floored at 0
  - `station:draw()` — draws a circle at `(x, y)`:
    - Radius: `4 + math.sqrt(crowd) * 0.15`, clamped 4–40
    - Color: green `(0.2, 0.8, 0.3)` at 0 crowd → yellow `(1, 0.85, 0)` at 500 → red `(0.9, 0.2, 0.1)` at 2000+, linearly interpolated
    - Draw station name as tiny text (8px) on hover (check mouse within radius)

- [x] **B3** — `game/subway/train.lua` — Write a Lua module for a single train entity:
  - `Train.new(route_id, color, stop_sequence)` where `stop_sequence` is `{station_id, arrival_seconds}[]`
  - Fields: `route_id`, `color`, `stop_sequence`, `leg` (current index, 1-based), `progress` (0–1), `x`, `y`, `active=true`, `direction` (+1 or -1 for custom lines)
  - `train:update(dt_seconds, stations)` — advances `progress` based on time between current and next stop; when progress ≥ 1, moves to next leg; sets `x, y` by lerping between current and next station screen coords; when reaching final stop, sets `active=false`
  - `train:draw()` — small filled circle (radius 4) in `color`, plus a 1px white outline

- [x] **B4** — `game/subway/map.lua` — Write a Lua module handling projection and background rendering:
  - `Map.new(canvas_w, canvas_h)` with Manhattan bounding box constants (lat 40.700–40.882, lon -74.020–-73.907)
  - `map:project(lat, lon)` → `x, y` in canvas pixels (Mercator: x linear on lon, y linear on `log(tan(π/4 + lat_rad/2))`)
  - `map:draw_background()` — draws the Manhattan borough outline as a dim filled polygon `(0.12, 0.12, 0.15, 1)` using a hardcoded Lua table of ~40 lat/lon vertices (approximate Manhattan coastline — hardcode a simplified polygon, do not fetch at runtime)
  - `map:draw_lines(network, stations)` — for each active line in `network.lines`, draws a polyline in that line's color (alpha 0.6, line width 2) through its stops' screen positions
  - `map:draw_stations(station_list)` — calls `station:draw()` for each station
  - `map:draw_trains(train_list)` — calls `train:draw()` for each active train
  - `map:screen_to_world(sx, sy, cam)` → canvas coords accounting for camera pan/zoom

- [x] **B5** — `game/subway/passenger_flow.lua` — Write a Lua module that feeds ridership data into station crowds:
  - `PassengerFlow.new(ridership_data)` — holds the parsed `data/ridership.json` table
  - `flow:update(dt_minutes, sim_hour, sim_day_of_week, stations)` — for each station, adds `ridership[station.id][sim_day_of_week][sim_hour] / 60 * dt_minutes` to `station.crowd`; silently skips stations with no ridership data

---

## Group C — Scheduler and UI (depend on B)

- [x] **C1** — `game/subway/train_scheduler.lua` — Write a Lua module that owns the sim clock and manages train spawning:
  - `Scheduler.new(network)` — initialises `sim_time=0` (seconds since midnight), `sim_speed=60` (sim-seconds per real-second), `active_trains={}`
  - `scheduler:update(dt, stations)`:
    1. Advance `sim_time += dt * sim_speed`; wrap at 86400 (midnight rollover)
    2. For each active MTA line in `network.lines`: scan its trips for any whose first stop `arrival_seconds` just passed this tick — spawn a `Train` for each
    3. For each active custom line: compute headway = `round_trip_seconds / (num_trains / 2)`; spawn trains at evenly-spaced offsets, one per direction
    4. Call `train:update(dt * sim_speed, stations)` on each active train; remove trains where `active=false`
    5. For each train that just advanced to a new stop: call `station:board_train(8000)` on that stop's station
  - `scheduler:set_speed(s)` — sets `sim_speed`, clamped 1–600
  - `scheduler:get_sim_time()` → `{day_of_week (1–7), hour (0–23), minute (0–59)}`
  - Depends on B1, B2, B3

- [x] **C2** — `game/subway/line_editor.lua` — Write a Lua module that renders the sidebar and handles line editing input:
  - Sidebar is a fixed 200px panel on the right edge of the canvas (so map area is 1080×720)
  - **View mode**: scrollable list of lines; each row shows a colored swatch, the line name, a toggle button (`[on]`/`[off]`), and a delete button (`[x]`); clicking toggle calls `network:set_line_active`; clicking delete calls `network:remove_line` and signals the scheduler to clear that line's trains
  - **Draw mode** (entered via `[+ New Line]` button at top of sidebar):
    - Show 8 color swatches for picking line color; default selects first
    - In draw mode, `mousepressed` on the map snaps to nearest station within 20 screen-px; adds it to `pending_stops[]`; draws a preview polyline from first stop through pending stops to current cursor
    - `[Done]` / Enter confirms if `#pending_stops >= 2`: calls `network:add_custom_line`, exits draw mode
    - `[Cancel]` / Escape clears pending stops, exits draw mode
  - For each custom line in view mode: show `[−] N [+]` train count control (1–20); changing it calls `scheduler:set_custom_train_count(line_id, n)`
  - `editor:draw()` — renders the sidebar panel (dark background `(0.1, 0.1, 0.12, 1)`) and all its controls using `love.graphics` primitives and `love.graphics.print`
  - `editor:mousepressed(x, y, btn)`, `editor:mousemoved(x, y)`, `editor:keypressed(key)` — handle all interaction; return `true` if the event was consumed (so the map doesn't also handle it)
  - Depends on B1, C1

- [x] **C3** — `game/scenes/subway_scene.lua` — Write the main scene that wires everything together:
  - Extends `Scene` from `lua/core/scene.lua`
  - `SubwayScene.new()` — creates the scene at 1280×720
  - `scene:on_enter()`:
    - Creates `Network`, calls `network:load()`
    - Creates `Map.new(1080, 720)` (map area excludes sidebar)
    - Projects all station lat/lon to screen coords and stores on each station object
    - Creates `PassengerFlow` with ridership data
    - Creates `Scheduler.new(network)`
    - Creates `LineEditor.new(network, scheduler, map)`
    - Owns camera state: `cam = {x=0, y=0, zoom=1.0}`; initial position centers on Manhattan
  - `scene:update(dt)`:
    - Handle pan: if left mouse held outside sidebar, track drag delta → update `cam.x/y`
    - Handle zoom: `love.wheelmoved` → `cam.zoom *= 1.1^dy`, clamped 0.5–4
    - Handle speed keys: `+`/`-` → `scheduler:set_speed`
    - Call `scheduler:update(dt, stations)`
    - Call `flow:update(dt_minutes, sim_hour, sim_dow, stations)`
    - Forward mouse/key events to `line_editor`
  - `scene:draw()`:
    - Apply camera transform (translate + scale around canvas centre)
    - Call `map:draw_background()`
    - Call `map:draw_lines(network, stations)`
    - Call `map:draw_stations(station_list)`
    - Call `map:draw_trains(scheduler.active_trains)`
    - Pop camera transform
    - Call `line_editor:draw()` (sidebar, always screen-space)
    - Draw HUD: sim day name + time (top-left), speed indicator
  - Depends on B1–B5, C1, C2

- [x] **C4** — `main.lua` — Change the initial scene from `GameScene` to `SubwayScene`:
  - Replace `local GameScene = require("game/scenes/game_scene")` with `local SubwayScene = require("game/scenes/subway_scene")`
  - Replace `manager:switch(GameScene.new())` with `manager:switch(SubwayScene.new())`
  - No other changes
  - Depends on C3
