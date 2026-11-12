-- game/subway/line_editor.lua
-- Sidebar UI for viewing, toggling, deleting, and drawing subway lines.
-- Sidebar occupies x=1080..1280 (200px wide) on the 1280x720 canvas.
-- All sidebar coordinates are in screen space (not affected by camera).

local LineEditor = {}
LineEditor.__index = LineEditor

local SIDEBAR_X    = 1080
local SIDEBAR_W    = 200
local SIDEBAR_H    = 720
local ROW_H        = 36   -- standard row height
local CUSTOM_ROW_H = 54   -- taller row for custom lines (fits train count row)
local SNAP_RADIUS  = 20   -- screen-px snap distance for draw mode

-- ── Constructor ───────────────────────────────────────────────────────────────

-- network   : Network instance
-- scheduler : Scheduler instance
-- map       : Map instance (for project() and screen_to_world())
function LineEditor.new(network, scheduler, map)
  local self = setmetatable({}, LineEditor)

  self.network   = network
  self.scheduler = scheduler
  self.map       = map

  self.mode          = "view"   -- "view" | "draw"
  self.scroll        = 0        -- pixel offset for scrolling the line list
  self.pending_stops = {}       -- station_ids collected in draw mode
  self.pending_color = { r = 255, g = 100, b = 100 }

  self.cursor_x  = 0   -- current mouse position in canvas coords
  self.cursor_y  = 0
  self.cursor_sx = 0   -- screen coords (for sidebar hit testing)
  self.cursor_sy = 0

  self._custom_count    = 0
  self._color_swatches  = {
    { 255, 100, 100 }, { 100, 180, 255 }, { 100, 220, 100 },
    { 255, 200, 50  }, { 200, 100, 255 }, { 255, 150, 50  },
    {  80, 220, 200 }, { 200, 200, 200 },
  }
  self._selected_swatch = 1

  return self
end

-- ── Internal helpers ──────────────────────────────────────────────────────────

-- Returns lines sorted: MTA lines first (by name), then custom lines (by name).
function LineEditor:_sorted_lines()
  local mta    = {}
  local custom = {}
  for _, line in pairs(self.network.lines) do
    if not line.deleted then
      if line.is_custom then
        custom[#custom + 1] = line
      else
        mta[#mta + 1] = line
      end
    end
  end
  table.sort(mta,    function(a, b) return a.name < b.name end)
  table.sort(custom, function(a, b) return a.name < b.name end)
  for _, line in ipairs(custom) do
    mta[#mta + 1] = line
  end
  return mta
end

-- Confirm draw mode: add the custom line and reset draw state.
function LineEditor:_confirm_draw()
  if #self.pending_stops < 2 then return end

  self._custom_count = self._custom_count + 1
  local color = {
    r = self.pending_color.r,
    g = self.pending_color.g,
    b = self.pending_color.b,
  }
  local line_id = self.network:add_custom_line(self.pending_stops, color, 4)
  -- Scheduler may not exist yet during unit testing; guard safely.
  if self.scheduler and self.scheduler.set_custom_train_count then
    -- trains are set to 4 by add_custom_line; no extra call needed.
  end

  self:_cancel_draw()
end

-- Cancel draw mode: clear pending stops and return to view mode.
function LineEditor:_cancel_draw()
  self.pending_stops = {}
  self.mode          = "view"
end

-- Convert 0-255 color to 0-1 for love.graphics.
local function c(r, g, b, a)
  return r / 255, g / 255, b / 255, (a or 255) / 255
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

function LineEditor:draw()
  local lg = love.graphics

  -- Sidebar background
  lg.setColor(0.1, 0.1, 0.12, 1)
  lg.rectangle("fill", SIDEBAR_X, 0, SIDEBAR_W, SIDEBAR_H)

  -- 1px separator at left edge
  lg.setColor(0.3, 0.3, 0.35, 1)
  lg.setLineWidth(1)
  lg.line(SIDEBAR_X, 0, SIDEBAR_X, SIDEBAR_H)

  if self.mode == "view" then
    self:_draw_view_mode()
  else
    self:_draw_draw_mode()
  end
end

function LineEditor:_draw_view_mode()
  local lg = love.graphics

  -- "[+ New Line]" button at top
  local btn_x  = SIDEBAR_X + 10
  local btn_y  = 10
  local btn_w  = SIDEBAR_W - 20
  local btn_h  = 24
  local mx, my = self.cursor_sx, self.cursor_sy
  local hovered_btn = mx >= btn_x and mx <= btn_x + btn_w and
                       my >= btn_y and my <= btn_y + btn_h

  lg.setColor(hovered_btn and 0.25 or 0.18, 0.4, 0.25, 1)
  lg.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 3, 3)
  lg.setColor(0.5, 0.9, 0.55, 1)
  lg.printf("[+ New Line]", btn_x, btn_y + 5, btn_w, "center")

  -- Clip to sidebar for scrollable list
  lg.setScissor(SIDEBAR_X, 44, SIDEBAR_W, SIDEBAR_H - 44)

  local lines   = self:_sorted_lines()
  local list_y  = 50 - self.scroll  -- y within canvas (before scissor offset)

  for _, line in ipairs(lines) do
    local row_h = line.is_custom and CUSTOM_ROW_H or ROW_H
    local ry    = list_y  -- absolute canvas y of this row

    -- Only draw rows that are (at least partially) visible
    if ry + row_h >= 44 and ry <= SIDEBAR_H then
      -- Row hover background
      local row_hover = mx >= SIDEBAR_X and mx <= SIDEBAR_X + SIDEBAR_W and
                         my >= ry and my <= ry + row_h
      if row_hover then
        lg.setColor(0.18, 0.18, 0.22, 1)
        lg.rectangle("fill", SIDEBAR_X, ry, SIDEBAR_W, row_h)
      end

      -- Colored swatch (12x12)
      local cr, cg, cb = c(line.color.r, line.color.g, line.color.b)
      lg.setColor(cr, cg, cb, 1)
      lg.rectangle("fill", SIDEBAR_X + 6, ry + 12, 12, 12)

      -- Line name (truncated)
      local name = line.name
      if #name > 14 then name = name:sub(1, 13) .. "…" end
      lg.setColor(0.9, 0.9, 0.9, 1)
      lg.print(name, SIDEBAR_X + 22, ry + 10)

      -- Delete button "[x]" far right
      local del_w  = 20
      local del_x  = SIDEBAR_X + SIDEBAR_W - del_w - 4
      local del_y  = ry + 10
      local del_hv = mx >= del_x and mx <= del_x + del_w and
                      my >= del_y and my <= del_y + 14
      lg.setColor(del_hv and 0.9 or 0.6, 0.2, 0.2, 1)
      lg.print("[x]", del_x, del_y)

      -- Toggle button "[on]"/"[off]" to the left of delete
      local tog_w  = 32
      local tog_x  = del_x - tog_w - 4
      local tog_y  = ry + 10
      local tog_hv = mx >= tog_x and mx <= tog_x + tog_w and
                      my >= tog_y and my <= tog_y + 14
      if line.active then
        lg.setColor(tog_hv and 0.4 or 0.25, tog_hv and 0.95 or 0.75, 0.3, 1)
        lg.print("[on]", tog_x, tog_y)
      else
        lg.setColor(tog_hv and 0.7 or 0.5, 0.15, 0.15, 1)
        lg.print("[off]", tog_x - 8, tog_y)
      end

      -- Train count control for custom lines: [-] N [+]
      if line.is_custom then
        local num  = line.num_trains or 4
        local ty2  = ry + ROW_H + 4

        local minus_x = SIDEBAR_X + 20
        local plus_x  = SIDEBAR_X + SIDEBAR_W - 24
        local mn_hv   = mx >= minus_x and mx <= minus_x + 16 and
                         my >= ty2 and my <= ty2 + 16
        local pl_hv   = mx >= plus_x and mx <= plus_x + 16 and
                         my >= ty2 and my <= ty2 + 16

        lg.setColor(mn_hv and 0.9 or 0.65, 0.65, 0.65, 1)
        lg.print("[-]", minus_x, ty2)

        lg.setColor(0.85, 0.85, 0.85, 1)
        lg.printf(tostring(num), SIDEBAR_X, ty2, SIDEBAR_W, "center")

        lg.setColor(pl_hv and 0.9 or 0.65, 0.65, 0.65, 1)
        lg.print("[+]", plus_x, ty2)
      end

      -- Thin separator
      lg.setColor(0.22, 0.22, 0.26, 1)
      lg.line(SIDEBAR_X, ry + row_h, SIDEBAR_X + SIDEBAR_W, ry + row_h)
    end

    list_y = list_y + row_h
  end

  -- Clamp scroll max so the list doesn't scroll past the last item
  self._max_scroll = math.max(0, list_y - (50 - self.scroll) - (SIDEBAR_H - 50))

  lg.setScissor()
end

function LineEditor:_draw_draw_mode()
  local lg = love.graphics

  -- Header
  lg.setColor(0.9, 0.85, 0.3, 1)
  lg.printf("Drawing new line", SIDEBAR_X, 10, SIDEBAR_W, "center")

  -- Color swatches: 2 rows of 4, each 20x20, with 6px gap
  local sw_start_x = SIDEBAR_X + 10
  local sw_start_y = 36
  local sw_size    = 20
  local sw_gap     = 6

  for i, sw in ipairs(self._color_swatches) do
    local col  = (i - 1) % 4
    local row  = math.floor((i - 1) / 4)
    local sx   = sw_start_x + col * (sw_size + sw_gap)
    local sy   = sw_start_y + row * (sw_size + sw_gap)

    lg.setColor(c(sw[1], sw[2], sw[3], 255))
    lg.rectangle("fill", sx, sy, sw_size, sw_size, 2, 2)

    -- White border if selected
    if i == self._selected_swatch then
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(2)
      lg.rectangle("line", sx - 1, sy - 1, sw_size + 2, sw_size + 2, 2, 2)
      lg.setLineWidth(1)
    end
  end

  -- Stop count
  local n_stops = #self.pending_stops
  lg.setColor(0.75, 0.75, 0.75, 1)
  lg.printf("Stops: " .. n_stops, SIDEBAR_X, 92, SIDEBAR_W, "center")

  -- [Done] button (green, only if >= 2 stops)
  local done_x = SIDEBAR_X + 10
  local done_y = 112
  local done_w = 80
  local done_h = 24
  local mx, my = self.cursor_sx, self.cursor_sy
  local can_done = n_stops >= 2

  if can_done then
    local done_hv = mx >= done_x and mx <= done_x + done_w and
                     my >= done_y and my <= done_y + done_h
    lg.setColor(done_hv and 0.3 or 0.2, done_hv and 0.75 or 0.6, 0.25, 1)
    lg.rectangle("fill", done_x, done_y, done_w, done_h, 3, 3)
    lg.setColor(0.9, 1, 0.9, 1)
    lg.printf("[Done]", done_x, done_y + 5, done_w, "center")
  else
    lg.setColor(0.25, 0.25, 0.28, 1)
    lg.rectangle("fill", done_x, done_y, done_w, done_h, 3, 3)
    lg.setColor(0.45, 0.45, 0.45, 1)
    lg.printf("[Done]", done_x, done_y + 5, done_w, "center")
  end

  -- [Cancel] button (red)
  local can_x = SIDEBAR_X + 110
  local can_y = done_y
  local can_w = 80
  local can_h = done_h
  local can_hv = mx >= can_x and mx <= can_x + can_w and
                  my >= can_y and my <= can_y + can_h
  lg.setColor(can_hv and 0.7 or 0.5, 0.15, 0.15, 1)
  lg.rectangle("fill", can_x, can_y, can_w, can_h, 3, 3)
  lg.setColor(1, 0.75, 0.75, 1)
  lg.printf("[Cancel]", can_x, can_y + 5, can_w, "center")

  -- Map overlay: preview polyline through pending stops
  local pc = self.pending_color
  local pr, pg, pb = c(pc.r, pc.g, pc.b, 204)  -- alpha 0.8

  if n_stops >= 1 then
    -- Collect screen positions for pending stops
    local pts = {}
    for _, sid in ipairs(self.pending_stops) do
      local st = self.network.stations[sid]
      if st then
        pts[#pts + 1] = { st.x, st.y }
      end
    end

    -- Draw polyline
    if #pts >= 2 then
      love.graphics.setColor(pr, pg, pb, 0.8)
      love.graphics.setLineWidth(3)
      for i = 1, #pts - 1 do
        love.graphics.line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
      end
      love.graphics.setLineWidth(1)
    end

    -- Solid thin line from last stop to cursor (in map area)
    if self.cursor_x < SIDEBAR_X then
      local last = pts[#pts]
      if last then
        love.graphics.setColor(pr, pg, pb, 0.6)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(last[1], last[2], self.cursor_x, self.cursor_y)
        love.graphics.setLineWidth(1)
      end
    end
  end

  -- Highlight nearest snappable station with a white ring
  local snap_st = self:_nearest_station_screen(self.cursor_sx, self.cursor_sy)
  if snap_st then
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", snap_st.x, snap_st.y, 8)
    love.graphics.setLineWidth(1)
  end
end

-- ── Interaction ───────────────────────────────────────────────────────────────

-- Returns true if the event was consumed (don't pass to map/camera).
function LineEditor:mousepressed(x, y, button, cam)
  if button ~= 1 then return false end

  local mx, my = x, y  -- screen coords

  if mx >= SIDEBAR_X then
    -- Click is in sidebar
    return self:_sidebar_click(mx, my)
  else
    -- Click is on map
    if self.mode == "draw" then
      return self:_map_click_draw(mx, my, cam)
    end
    return false
  end
end

function LineEditor:_sidebar_click(mx, my)
  if self.mode == "view" then
    -- "[+ New Line]" button
    local btn_x = SIDEBAR_X + 10
    local btn_y = 10
    local btn_w = SIDEBAR_W - 20
    local btn_h = 24
    if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
      self.mode = "draw"
      self.pending_stops = {}
      self._selected_swatch = 1
      local sw = self._color_swatches[1]
      self.pending_color = { r = sw[1], g = sw[2], b = sw[3] }
      return true
    end

    -- Scrollable line list
    local lines  = self:_sorted_lines()
    local list_y = 50 - self.scroll

    for _, line in ipairs(lines) do
      local row_h = line.is_custom and CUSTOM_ROW_H or ROW_H
      local ry    = list_y

      if my >= ry and my <= ry + row_h then
        -- Toggle button
        local del_w = 20
        local del_x = SIDEBAR_X + SIDEBAR_W - del_w - 4
        local tog_w = 32
        local tog_x = del_x - tog_w - 4

        -- Delete button
        if mx >= del_x and mx <= del_x + del_w and my >= ry + 10 and my <= ry + 24 then
          self.network:remove_line(line.id)
          if self.scheduler and self.scheduler.remove_line_trains then
            self.scheduler:remove_line_trains(line.id)
          end
          return true
        end

        -- Toggle button
        if mx >= tog_x and mx <= del_x and my >= ry + 10 and my <= ry + 24 then
          self.network:set_line_active(line.id, not line.active)
          return true
        end

        -- Train count controls for custom lines
        if line.is_custom then
          local ty2     = ry + ROW_H + 4
          local minus_x = SIDEBAR_X + 20
          local plus_x  = SIDEBAR_X + SIDEBAR_W - 24

          if my >= ty2 and my <= ty2 + 16 then
            if mx >= minus_x and mx <= minus_x + 20 then
              local num = math.max(1, (line.num_trains or 4) - 1)
              line.num_trains = num
              if self.scheduler and self.scheduler.set_custom_train_count then
                self.scheduler:set_custom_train_count(line.id, num)
              end
              return true
            end
            if mx >= plus_x and mx <= plus_x + 20 then
              local num = math.min(20, (line.num_trains or 4) + 1)
              line.num_trains = num
              if self.scheduler and self.scheduler.set_custom_train_count then
                self.scheduler:set_custom_train_count(line.id, num)
              end
              return true
            end
          end
        end

        return true  -- consumed even if no specific button hit (row click)
      end

      list_y = list_y + row_h
    end

  elseif self.mode == "draw" then
    -- Color swatches
    local sw_start_x = SIDEBAR_X + 10
    local sw_start_y = 36
    local sw_size    = 20
    local sw_gap     = 6

    for i = 1, #self._color_swatches do
      local col = (i - 1) % 4
      local row = math.floor((i - 1) / 4)
      local sx  = sw_start_x + col * (sw_size + sw_gap)
      local sy  = sw_start_y + row * (sw_size + sw_gap)
      if mx >= sx and mx <= sx + sw_size and my >= sy and my <= sy + sw_size then
        self._selected_swatch = i
        local sw = self._color_swatches[i]
        self.pending_color = { r = sw[1], g = sw[2], b = sw[3] }
        return true
      end
    end

    -- [Done] button
    local done_x = SIDEBAR_X + 10
    local done_y = 112
    local done_w = 80
    local done_h = 24
    if mx >= done_x and mx <= done_x + done_w and my >= done_y and my <= done_y + done_h then
      self:_confirm_draw()
      return true
    end

    -- [Cancel] button
    local can_x = SIDEBAR_X + 110
    local can_y = done_y
    local can_w = 80
    local can_h = done_h
    if mx >= can_x and mx <= can_x + can_w and my >= can_y and my <= can_y + can_h then
      self:_cancel_draw()
      return true
    end
  end

  return false
end

function LineEditor:_map_click_draw(mx, my, cam)
  -- Find nearest station within SNAP_RADIUS screen pixels
  local snap_st = self:_nearest_station_screen(mx, my)
  if snap_st then
    -- Avoid adding the same station twice in a row
    local last = self.pending_stops[#self.pending_stops]
    if last ~= snap_st.id then
      self.pending_stops[#self.pending_stops + 1] = snap_st.id
    end
    return true
  end
  return false
end

-- Find the nearest station within SNAP_RADIUS screen pixels.
-- Station screen positions are stored as canvas coords (station.x, station.y).
-- We need to convert station canvas coords to screen coords using the camera.
-- But the map module's screen_to_world inverts: screen → canvas.
-- Here we need canvas → screen for comparison. We approximate using cursor screen coords.
-- Since cursor_sx/sy are screen coords and cursor_x/y are canvas coords, and
-- station.x/y are canvas coords, we find the nearest station in canvas space and
-- then check if its screen distance is within SNAP_RADIUS.
-- For simplicity and correctness, we find nearest in screen-pixel distance by
-- converting: screen_px ≈ canvas_px * zoom (for pan-adjusted positions).
-- We'll store the cam reference as self._last_cam in mousemoved.
function LineEditor:_nearest_station_screen(sx, sy)
  -- sx, sy are screen coords
  -- We compare against stations whose positions are in canvas coords.
  -- Use the last-known cam to convert station canvas → screen for distance check.
  local cam = self._last_cam
  if not cam then return nil end

  local map      = self.map
  local cw, ch   = map.canvas_w + 200, map.canvas_h  -- full canvas including sidebar
  local cx, cy   = cw / 2, ch / 2  -- but map canvas center for the map area
  -- Actually, the map is 1080 wide. Use the map's canvas dimensions.
  local mc_x = map.canvas_w / 2
  local mc_y = map.canvas_h / 2

  local best_dist = SNAP_RADIUS + 1
  local best_st   = nil

  for _, st in pairs(self.network.stations) do
    -- Convert station canvas (st.x, st.y) → screen
    local screen_x = (st.x + cam.x - mc_x) * cam.zoom + mc_x
    local screen_y = (st.y + cam.y - mc_y) * cam.zoom + mc_y

    -- Only consider stations in the map area
    if screen_x < SIDEBAR_X then
      local dx   = sx - screen_x
      local dy   = sy - screen_y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < best_dist then
        best_dist = dist
        best_st   = st
      end
    end
  end

  return best_st
end

function LineEditor:mousemoved(x, y, cam)
  self._last_cam = cam
  -- Update screen coords
  self.cursor_sx = x
  self.cursor_sy = y
  -- Convert to canvas coords
  if cam and self.map then
    self.cursor_x, self.cursor_y = self.map:screen_to_world(x, y, cam)
  else
    self.cursor_x = x
    self.cursor_y = y
  end
end

function LineEditor:wheelmoved(dy)
  if self.cursor_sx >= SIDEBAR_X and self.mode == "view" then
    self.scroll = math.max(0, self.scroll - dy * 20)
  end
end

-- Returns true if key was consumed.
function LineEditor:keypressed(key)
  if self.mode == "draw" then
    if key == "return" or key == "kpenter" then
      self:_confirm_draw()
      return true
    elseif key == "escape" then
      self:_cancel_draw()
      return true
    end
  end
  return false
end

return LineEditor
