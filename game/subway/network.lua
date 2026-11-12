-- game/subway/network.lua
-- Subway network data model.
-- Reads data/stations.json, data/routes.json, data/trips.json via love.filesystem.
-- Usage:
--   local Network = require("game/subway/network")
--   local net = Network.load()

local JSON = require("lua/util/json")

local Network = {}
Network.__index = Network

-- ── helpers ────────────────────────────────────────────────────────────────

local function read_json(path)
  local data, err = love.filesystem.read(path)
  if not data then
    error("network: cannot read " .. path .. ": " .. tostring(err))
  end
  return JSON.decode(data)
end

-- Build the ordered unique stop list for a route from all its trips.
-- Uses the first trip's order as the canonical sequence, then appends any
-- stations from subsequent trips that weren't already included.
local function build_line_stops(trips_for_route)
  if not trips_for_route or #trips_for_route == 0 then return {} end

  local seen = {}
  local stops = {}

  -- canonical order from first trip
  local first = trips_for_route[1]
  for _, stop in ipairs(first.stops) do
    local sid = stop.station_id
    if not seen[sid] then
      seen[sid] = true
      stops[#stops + 1] = sid
    end
  end

  -- append any new stations from remaining trips (in their listed order)
  for t = 2, #trips_for_route do
    for _, stop in ipairs(trips_for_route[t].stops) do
      local sid = stop.station_id
      if not seen[sid] then
        seen[sid] = true
        stops[#stops + 1] = sid
      end
    end
  end

  return stops
end

-- ── Network.load ───────────────────────────────────────────────────────────

function Network.load()
  local self = setmetatable({}, Network)

  -- ── stations ──────────────────────────────────────────────────────────
  -- self.stations = { [id] = {id, name, lat, lon, lines=[], x=0, y=0, crowd=0} }
  local stations_raw = read_json("data/stations.json")
  self.stations = {}
  for _, s in ipairs(stations_raw) do
    self.stations[s.id] = {
      id    = s.id,
      name  = s.name,
      lat   = s.lat,
      lon   = s.lon,
      lines = s.lines or {},
      x     = 0,
      y     = 0,
      crowd = 0,
    }
  end

  -- ── routes ────────────────────────────────────────────────────────────
  -- self.routes = { [id] = {id, short_name, color={r,g,b}} }
  local routes_raw = read_json("data/routes.json")
  self.routes = {}
  for _, r in ipairs(routes_raw) do
    self.routes[r.id] = {
      id         = r.id,
      short_name = r.short_name,
      color      = { r = r.color_r, g = r.color_g, b = r.color_b },
    }
  end

  -- ── trips ─────────────────────────────────────────────────────────────
  -- self.trips = { [route_id] = [{trip_id, stops=[{station_id, arrival_seconds}]}] }
  local trips_raw = read_json("data/trips.json")
  self.trips = {}
  for route_id, trip_list in pairs(trips_raw) do
    self.trips[route_id] = trip_list
  end

  -- ── lines ─────────────────────────────────────────────────────────────
  -- One line per route.  Stop sequence derived from trips.
  self.lines = {}
  self._custom_counter = 0

  for route_id, route in pairs(self.routes) do
    local trips_for_route = self.trips[route_id]
    local stops = build_line_stops(trips_for_route)
    self.lines[route_id] = {
      id         = route_id,
      name       = route.short_name,
      color      = { r = route.color.r, g = route.color.g, b = route.color.b },
      stops      = stops,
      active     = true,
      is_custom  = false,
      num_trains = nil,
      deleted    = false,
    }
  end

  return self
end

-- ── Network:add_custom_line ────────────────────────────────────────────────

function Network:add_custom_line(stops, color, num_trains)
  self._custom_counter = self._custom_counter + 1
  local line_id = "custom_" .. self._custom_counter
  self.lines[line_id] = {
    id         = line_id,
    name       = "Custom " .. self._custom_counter,
    color      = { r = color.r, g = color.g, b = color.b },
    stops      = stops,
    active     = true,
    is_custom  = true,
    num_trains = num_trains,
    deleted    = false,
  }
  return line_id
end

-- ── Network:remove_line ───────────────────────────────────────────────────

function Network:remove_line(line_id)
  local line = self.lines[line_id]
  if line then
    line.deleted = true
    line.active  = false
  end
end

-- ── Network:set_line_active ───────────────────────────────────────────────

function Network:set_line_active(line_id, active)
  local line = self.lines[line_id]
  if line and not line.deleted then
    line.active = active
  end
end

return Network
