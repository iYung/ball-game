local Map = {}
Map.__index = Map

-- canvas_w=1080, canvas_h=720
function Map.new(canvas_w, canvas_h)
  local self = setmetatable({}, Map)
  self.canvas_w = canvas_w
  self.canvas_h = canvas_h

  -- Manhattan bounding box (WGS-84)
  self.LAT_MIN = 40.700
  self.LAT_MAX = 40.882
  self.LON_MIN = -74.020
  self.LON_MAX = -73.907

  -- Padding around the edges in pixels
  self.PADDING = 20

  -- Precompute Mercator Y values for the bounding latitudes
  local function mercY(lat_deg)
    local lat_rad = math.rad(lat_deg)
    return math.log(math.tan(math.pi / 4 + lat_rad / 2))
  end

  self._merc_y_min = mercY(self.LAT_MIN)
  self._merc_y_max = mercY(self.LAT_MAX)

  return self
end

-- Convert WGS-84 lat/lon to map pixel coords using web Mercator projection.
-- x is linear on longitude; y is linear on log(tan(pi/4 + lat_rad/2)).
-- The bounding box maps to (PADDING, PADDING)–(canvas_w-PADDING, canvas_h-PADDING).
function Map:project(lat, lon)
  local pad = self.PADDING
  local draw_w = self.canvas_w - 2 * pad
  local draw_h = self.canvas_h - 2 * pad

  -- Normalise longitude linearly
  local tx = (lon - self.LON_MIN) / (self.LON_MAX - self.LON_MIN)

  -- Normalise latitude via Mercator; note: larger lat_rad → larger mercY,
  -- but screen y increases downward, so we invert.
  local merc_y = math.log(math.tan(math.pi / 4 + math.rad(lat) / 2))
  local ty = 1 - (merc_y - self._merc_y_min) / (self._merc_y_max - self._merc_y_min)

  local x = pad + tx * draw_w
  local y = pad + ty * draw_h
  return x, y
end

-- Inverse: canvas pixel → approximate lat/lon (useful for debugging).
function Map:unproject(x, y)
  local pad = self.PADDING
  local draw_w = self.canvas_w - 2 * pad
  local draw_h = self.canvas_h - 2 * pad

  local tx = (x - pad) / draw_w
  local ty = (y - pad) / draw_h

  local lon = self.LON_MIN + tx * (self.LON_MAX - self.LON_MIN)

  -- Invert ty to get Mercator Y, then invert Mercator projection
  local merc_y = self._merc_y_min + (1 - ty) * (self._merc_y_max - self._merc_y_min)
  local lat = math.deg(2 * math.atan(math.exp(merc_y)) - math.pi / 2)

  return lat, lon
end

-- Convert screen coords accounting for camera pan/zoom to canvas coords.
function Map:screen_to_world(sx, sy, cam)
  local cx = self.canvas_w / 2
  local cy = self.canvas_h / 2
  local wx = (sx - cx) / cam.zoom - cam.x + cx
  local wy = (sy - cy) / cam.zoom - cam.y + cy
  return wx, wy
end

-- Simplified Manhattan coastline polygon (~42 vertices), clockwise from the north tip.
-- Approximate lat/lon; accuracy within a few blocks.
local MANHATTAN_POLY = {
  -- Northern tip (Inwood / Fort Tryon area)
  {40.882, -73.930},
  -- NE corner moving down the Harlem River / East side
  {40.878, -73.907},
  {40.868, -73.910},
  {40.860, -73.912},
  {40.850, -73.916},
  {40.840, -73.920},
  {40.830, -73.922},
  {40.820, -73.924},
  {40.810, -73.927},
  {40.800, -73.930},
  {40.790, -73.933},
  {40.780, -73.936},
  {40.775, -73.940},
  {40.770, -73.942},
  {40.762, -73.948},
  {40.755, -73.955},
  {40.748, -73.960},
  {40.740, -73.969},
  {40.734, -73.975},
  {40.727, -73.980},
  {40.720, -73.986},
  {40.712, -73.993},
  {40.706, -74.000},
  -- SE tip (tip of Lower Manhattan / Battery Park)
  {40.700, -74.013},
  -- West side going north along the Hudson River
  {40.703, -74.016},
  {40.708, -74.017},
  {40.714, -74.016},
  {40.720, -74.015},
  {40.728, -74.014},
  {40.735, -74.012},
  {40.742, -74.011},
  {40.750, -74.010},
  {40.758, -74.009},
  {40.766, -74.008},
  {40.774, -74.007},
  {40.782, -74.004},
  {40.790, -74.001},
  {40.800, -73.999},
  {40.812, -73.997},
  {40.824, -73.952},
  {40.840, -73.942},
  {40.856, -73.934},
  -- Back to north tip
  {40.882, -73.930},
}

-- Draw the Manhattan borough outline as a dim filled polygon.
function Map:draw_background()
  -- Build flat vertex list for love.graphics.polygon
  local verts = {}
  for _, pt in ipairs(MANHATTAN_POLY) do
    local x, y = self:project(pt[1], pt[2])
    verts[#verts + 1] = x
    verts[#verts + 1] = y
  end

  -- Filled polygon
  love.graphics.setColor(0.12, 0.12, 0.18, 1.0)
  love.graphics.polygon("fill", verts)

  -- Outline (slightly lighter)
  love.graphics.setColor(0.2, 0.2, 0.28, 1.0)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line", verts)
end

-- Draw line polylines for all active, non-deleted lines.
function Map:draw_lines(network, stations)
  if not network or not network.lines then return end

  love.graphics.setLineWidth(2)

  for _, line in pairs(network.lines) do
    -- Skip inactive or deleted lines, or lines with fewer than 2 stops
    if line.active and not line.deleted and line.stops and #line.stops >= 2 then
      local c = line.color or {r = 1, g = 1, b = 1}
      love.graphics.setColor(c.r, c.g, c.b, 0.5)

      -- Collect valid screen positions
      local verts = {}
      for _, sid in ipairs(line.stops) do
        local st = stations[sid]
        if st and st.x and st.x > 0 then
          verts[#verts + 1] = st.x
          verts[#verts + 1] = st.y
        end
      end

      -- Need at least 2 points (4 numbers) to draw a line
      if #verts >= 4 then
        love.graphics.line(verts)
      end
    end
  end

  love.graphics.setLineWidth(1)
end

-- Call station:draw(mx, my) for each station in the list.
-- mx, my = mouse position in canvas coords (already adjusted for camera).
function Map:draw_stations(station_list, mx, my)
  if not station_list then return end
  for _, station in ipairs(station_list) do
    station:draw(mx, my)
  end
end

-- Call train:draw() for each active train in the list.
function Map:draw_trains(train_list)
  if not train_list then return end
  for _, train in ipairs(train_list) do
    if train.active then
      train:draw()
    end
  end
end

return Map
