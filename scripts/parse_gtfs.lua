-- parse_gtfs.lua
-- Standalone Lua script (run with: lua scripts/parse_gtfs.lua)
-- Reads GTFS files from data/raw/gtfs/ and writes three JSON files.

local BASE = "data/raw/gtfs/"

-- ─── tiny CSV parser ────────────────────────────────────────────────────────
-- Returns header table and an iterator that yields one row-table per line.
local function csv_parse_header(line)
  local headers = {}
  for field in (line .. ","):gmatch("([^,]*),") do
    headers[#headers + 1] = field:match("^%s*(.-)%s*$") -- trim whitespace
  end
  return headers
end

local function csv_split(line, nfields)
  local row = {}
  -- Simple split on comma; GTFS fields can be quoted but MTA GTFS mostly isn't
  -- We handle quoted fields to be safe.
  local i = 1
  local len = #line
  while i <= len and #row < nfields do
    if line:sub(i, i) == '"' then
      -- quoted field
      local j = i + 1
      local val = {}
      while j <= len do
        if line:sub(j, j) == '"' then
          if line:sub(j + 1, j + 1) == '"' then
            val[#val + 1] = '"'
            j = j + 2
          else
            j = j + 1 -- skip closing quote
            break
          end
        else
          val[#val + 1] = line:sub(j, j)
          j = j + 1
        end
      end
      row[#row + 1] = table.concat(val)
      -- skip comma
      if line:sub(j, j) == "," then j = j + 1 end
      i = j
    else
      local j = line:find(",", i, true)
      if j then
        row[#row + 1] = line:sub(i, j - 1)
        i = j + 1
      else
        row[#row + 1] = line:sub(i)
        i = len + 1
      end
    end
  end
  -- pad missing fields
  while #row < nfields do row[#row + 1] = "" end
  return row
end

-- Open a file and iterate rows as {field=value} tables
local function open_csv(path)
  local f = io.open(path, "r")
  if not f then error("Cannot open: " .. path) end
  local header_line = f:read("*l")
  if not header_line then f:close(); return function() end end
  -- strip BOM if present
  if header_line:sub(1, 3) == "\xEF\xBB\xBF" then
    header_line = header_line:sub(4)
  end
  local headers = csv_parse_header(header_line)
  local nfields = #headers

  return function()
    local line = f:read("*l")
    if not line then f:close(); return nil end
    if line == "" then return {} end
    local vals = csv_split(line, nfields)
    local row = {}
    for i, h in ipairs(headers) do
      row[h] = vals[i] or ""
    end
    return row
  end, headers
end

-- ─── tiny JSON serialiser ────────────────────────────────────────────────────
local function json_str(s)
  s = tostring(s)
  s = s:gsub('\\', '\\\\')
  s = s:gsub('"', '\\"')
  s = s:gsub('\n', '\\n')
  s = s:gsub('\r', '\\r')
  s = s:gsub('\t', '\\t')
  return '"' .. s .. '"'
end

local json_val  -- forward declaration
local function json_arr(t)
  local parts = {}
  for _, v in ipairs(t) do
    parts[#parts + 1] = json_val(v)
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function json_obj(t)
  local parts = {}
  for k, v in pairs(t) do
    parts[#parts + 1] = json_str(k) .. ":" .. json_val(v)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

json_val = function(v)
  local t = type(v)
  if t == "number" then
    -- integer check
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.8g", v)
  elseif t == "string" then
    return json_str(v)
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "table" then
    -- detect array vs object: array has only sequential integer keys from 1
    if #v > 0 then
      return json_arr(v)
    else
      return json_obj(v)
    end
  elseif t == "nil" then
    return "null"
  else
    return json_str(tostring(v))
  end
end

-- pretty-print an array of objects with one object per line
local function json_pretty_arr(arr)
  if #arr == 0 then return "[]" end
  local parts = {}
  for _, v in ipairs(arr) do
    parts[#parts + 1] = "  " .. json_val(v)
  end
  return "[\n" .. table.concat(parts, ",\n") .. "\n]"
end

-- pretty-print object keyed by route_id, each value is an array
local function json_pretty_trips(trips)
  local keys = {}
  for k in pairs(trips) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then return "{}" end
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = "  " .. json_str(k) .. ": " .. json_val(trips[k])
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n}"
end

-- ─── Manhattan filter ────────────────────────────────────────────────────────
local LAT_MIN, LAT_MAX = 40.700, 40.882
local LON_MIN, LON_MAX = -74.020, -73.907

local function in_manhattan(lat, lon)
  return lat >= LAT_MIN and lat <= LAT_MAX
     and lon >= LON_MIN and lon <= LON_MAX
end

-- ─── hex colour parser ───────────────────────────────────────────────────────
local function hex_to_rgb(hex)
  hex = hex:gsub("#", ""):upper()
  if #hex ~= 6 then return 0, 0, 0 end
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return r, g, b
end

-- ─── arrival_time → seconds ──────────────────────────────────────────────────
local function time_to_seconds(t)
  local h, m, s = t:match("(%d+):(%d+):(%d+)")
  if not h then return nil end
  return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Parse stops.txt
-- ════════════════════════════════════════════════════════════════════════════
print("[1/4] Parsing stops.txt ...")

-- raw_stops: stop_id -> {name, lat, lon, location_type, parent_station}
local raw_stops = {}
local iter = open_csv(BASE .. "stops.txt")
local row = iter()
while row do
  if row.stop_id and row.stop_id ~= "" then
    local lat = tonumber(row.stop_lat) or 0
    local lon = tonumber(row.stop_lon) or 0
    raw_stops[row.stop_id] = {
      name           = row.stop_name or "",
      lat            = lat,
      lon            = lon,
      location_type  = row.location_type or "",
      parent_station = row.parent_station or "",
    }
  end
  row = iter()
end

-- Determine canonical station id for each stop_id
-- Rules:
--   location_type == "1" → parent station, its own id is canonical
--   location_type == "" or "0" with a non-empty parent_station → parent's id is canonical
--   otherwise → its own id
local function canonical_id(stop_id)
  local s = raw_stops[stop_id]
  if not s then return stop_id end
  if s.parent_station ~= "" then
    return s.parent_station
  end
  return stop_id
end

-- Build set of Manhattan station ids (canonical)
-- A station is in Manhattan if any of its stops (parent or child) has coords in range.
-- For parent stations: use their own lat/lon.
-- For child stops: check child lat/lon but attribute to canonical id.
local manhattan_stations = {}  -- canonical_id -> {name, lat, lon}

for sid, s in pairs(raw_stops) do
  if in_manhattan(s.lat, s.lon) then
    local cid = canonical_id(sid)
    if not manhattan_stations[cid] then
      -- prefer parent's data if available
      local cs = raw_stops[cid] or s
      manhattan_stations[cid] = {name = cs.name, lat = cs.lat, lon = cs.lon}
    end
  end
end

local n_stations = 0
for _ in pairs(manhattan_stations) do n_stations = n_stations + 1 end
print(string.format("    Found %d Manhattan stations.", n_stations))

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Parse routes.txt
-- ════════════════════════════════════════════════════════════════════════════
print("[2/4] Parsing routes.txt ...")

-- route_id -> {short_name, color_r, color_g, color_b}
local routes_raw = {}
iter = open_csv(BASE .. "routes.txt")
row = iter()
while row do
  if row.route_id and row.route_id ~= "" then
    local r, g, b = hex_to_rgb(row.route_color or "000000")
    routes_raw[row.route_id] = {
      short_name = row.route_short_name or row.route_id,
      color_r    = r,
      color_g    = g,
      color_b    = b,
    }
  end
  row = iter()
end
print(string.format("    Found %d routes.", (function() local n=0; for _ in pairs(routes_raw) do n=n+1 end; return n end)()))

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Parse trips.txt
-- ════════════════════════════════════════════════════════════════════════════
print("[3/4] Parsing trips.txt ...")

-- trip_id -> {route_id, direction_id}
local trip_meta = {}
iter = open_csv(BASE .. "trips.txt")
row = iter()
while row do
  if row.trip_id and row.trip_id ~= "" then
    trip_meta[row.trip_id] = {
      route_id     = row.route_id or "",
      direction_id = row.direction_id or "0",
    }
  end
  row = iter()
end
print(string.format("    Found %d trips.", (function() local n=0; for _ in pairs(trip_meta) do n=n+1 end; return n end)()))

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Parse stop_times.txt line by line (large file)
-- ════════════════════════════════════════════════════════════════════════════
print("[4/4] Parsing stop_times.txt (large file, streaming) ...")

-- Build stop_id -> canonical_id map for quick lookup (only Manhattan stops)
local stop_to_canonical = {}
for sid in pairs(raw_stops) do
  local cid = canonical_id(sid)
  if manhattan_stations[cid] then
    stop_to_canonical[sid] = cid
  end
end

-- trip_id -> [{station_id, arrival_seconds, stop_sequence}]
local trip_stops = {}  -- populated as we stream

-- Also track which route_short_names serve each canonical station
local station_lines = {}  -- canonical_id -> set of route_short_name

local f = io.open(BASE .. "stop_times.txt", "r")
if not f then error("Cannot open stop_times.txt") end

-- read and parse header
local hdr_line = f:read("*l")
if hdr_line:sub(1,3) == "\xEF\xBB\xBF" then hdr_line = hdr_line:sub(4) end
local st_headers = csv_parse_header(hdr_line)
-- find column indices
local col = {}
for i, h in ipairs(st_headers) do col[h] = i end

local line_count = 0
local line = f:read("*l")
while line do
  line_count = line_count + 1
  if line_count % 100000 == 0 then
    io.write(string.format("    ... %d rows processed\n", line_count))
    io.flush()
  end

  local vals = csv_split(line, #st_headers)
  local trip_id    = vals[col["trip_id"]]    or ""
  local stop_id    = vals[col["stop_id"]]    or ""
  local arr_time   = vals[col["arrival_time"]] or ""
  local stop_seq   = tonumber(vals[col["stop_sequence"]] or "0") or 0

  local cid = stop_to_canonical[stop_id]
  if cid and trip_id ~= "" then
    local secs = time_to_seconds(arr_time)
    if secs then
      if not trip_stops[trip_id] then trip_stops[trip_id] = {} end
      trip_stops[trip_id][#trip_stops[trip_id] + 1] = {
        station_id      = cid,
        arrival_seconds = secs,
        seq             = stop_seq,
      }
      -- record line serving this station
      local meta = trip_meta[trip_id]
      if meta then
        local rname = (routes_raw[meta.route_id] or {}).short_name or meta.route_id
        if not station_lines[cid] then station_lines[cid] = {} end
        station_lines[cid][rname] = true
      end
    end
  end

  line = f:read("*l")
end
f:close()
print(string.format("    Processed %d rows total.", line_count))

-- ════════════════════════════════════════════════════════════════════════════
-- Build Output 1 — stations.json
-- ════════════════════════════════════════════════════════════════════════════
print("Building stations.json ...")

local stations_arr = {}
for cid, info in pairs(manhattan_stations) do
  local lines_set = station_lines[cid] or {}
  local lines_list = {}
  for rname in pairs(lines_set) do lines_list[#lines_list + 1] = rname end
  table.sort(lines_list)
  stations_arr[#stations_arr + 1] = {
    id    = cid,
    name  = info.name,
    lat   = info.lat,
    lon   = info.lon,
    lines = lines_list,
  }
end
table.sort(stations_arr, function(a, b) return a.id < b.id end)

local sf = io.open("data/stations.json", "w")
if not sf then error("Cannot write data/stations.json") end
sf:write(json_pretty_arr(stations_arr))
sf:write("\n")
sf:close()
print(string.format("    Wrote %d stations.", #stations_arr))

-- ════════════════════════════════════════════════════════════════════════════
-- Build Output 2 — routes.json
-- ════════════════════════════════════════════════════════════════════════════
print("Building routes.json ...")

-- Which routes have at least one Manhattan stop?
local routes_with_manhattan = {}
for _, station in ipairs(stations_arr) do
  for _, rname in ipairs(station.lines) do
    -- find route_id by short_name
    for rid, rd in pairs(routes_raw) do
      if rd.short_name == rname then
        routes_with_manhattan[rid] = true
        break
      end
    end
  end
end

-- Also walk trip_meta to associate route_ids with Manhattan
for tid, stops in pairs(trip_stops) do
  if #stops >= 1 then
    local meta = trip_meta[tid]
    if meta then routes_with_manhattan[meta.route_id] = true end
  end
end

local routes_arr = {}
for rid, rd in pairs(routes_raw) do
  if routes_with_manhattan[rid] then
    routes_arr[#routes_arr + 1] = {
      id         = rid,
      short_name = rd.short_name,
      color_r    = rd.color_r,
      color_g    = rd.color_g,
      color_b    = rd.color_b,
    }
  end
end
table.sort(routes_arr, function(a, b) return a.id < b.id end)

local rf = io.open("data/routes.json", "w")
if not rf then error("Cannot write data/routes.json") end
rf:write(json_pretty_arr(routes_arr))
rf:write("\n")
rf:close()
print(string.format("    Wrote %d routes.", #routes_arr))

-- ════════════════════════════════════════════════════════════════════════════
-- Build Output 3 — trips.json
-- ════════════════════════════════════════════════════════════════════════════
print("Building trips.json ...")

-- trips_by_route: route_id -> [{trip_id, stops=[{station_id, arrival_seconds}]}]
local trips_by_route = {}

for tid, stop_list in pairs(trip_stops) do
  -- need >= 2 Manhattan stops
  if #stop_list >= 2 then
    -- sort by stop_sequence
    table.sort(stop_list, function(a, b) return a.seq < b.seq end)

    -- build clean stops array (deduplicate consecutive same station)
    local stops = {}
    local prev_sid = nil
    for _, st in ipairs(stop_list) do
      if st.station_id ~= prev_sid then
        stops[#stops + 1] = {
          station_id      = st.station_id,
          arrival_seconds = st.arrival_seconds,
        }
        prev_sid = st.station_id
      end
    end

    if #stops >= 2 then
      local meta = trip_meta[tid]
      if meta and meta.route_id ~= "" then
        local rid = meta.route_id
        if not trips_by_route[rid] then trips_by_route[rid] = {} end
        trips_by_route[rid][#trips_by_route[rid] + 1] = {
          trip_id = tid,
          stops   = stops,
        }
      end
    end
  end
end

local tf = io.open("data/trips.json", "w")
if not tf then error("Cannot write data/trips.json") end
tf:write(json_pretty_trips(trips_by_route))
tf:write("\n")
tf:close()

local nroutes = 0
local ntrips = 0
for rid, arr in pairs(trips_by_route) do
  nroutes = nroutes + 1
  ntrips = ntrips + #arr
end
print(string.format("    Wrote %d trips across %d routes.", ntrips, nroutes))

print("Done.")
