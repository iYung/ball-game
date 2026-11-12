local Scene         = require("lua/core/scene")
local JSON          = require("lua/util/json")
local Network       = require("game/subway/network")
local Map           = require("game/subway/map")
local Station       = require("game/subway/station")
local PassengerFlow = require("game/subway/passenger_flow")
local Scheduler     = require("game/subway/train_scheduler")
local LineEditor    = require("game/subway/line_editor")

local SubwayScene = {}
SubwayScene.__index = SubwayScene

function SubwayScene.new()
    local self = Scene.new(1280, 720)
    setmetatable(self, SubwayScene)
    return self
end

function SubwayScene:on_enter()
    -- 1. Load network (stations, routes, trips, lines)
    self.network = Network.load()

    -- 2. Create map (1080px wide — sidebar is 200px on the right)
    self.map = Map.new(1080, 720)

    -- 3. Project all station lat/lon → screen coords; build station objects.
    --    After Station.new(data), replace network.stations[id] with the station
    --    object so scheduler/flow operate on the same objects as self.stations.
    for id, data in pairs(self.network.stations) do
        local s = Station.new(data)
        s.x, s.y = self.map:project(data.lat, data.lon)
        self.network.stations[id] = s
    end
    -- self.stations shares the same table as self.network.stations
    self.stations = self.network.stations

    -- 4. Load ridership data and create PassengerFlow
    local ridership_str = love.filesystem.read("data/ridership.json")
    local ridership_data = ridership_str and JSON.decode(ridership_str) or {}
    self.flow = PassengerFlow.new(ridership_data)

    -- 5. Create scheduler
    self.scheduler = Scheduler.new(self.network)

    -- 6. Create line editor
    self.editor = LineEditor.new(self.network, self.scheduler, self.map)

    -- 7. Camera state (driven manually — not using Scene's built-in camera)
    self.cam = { x = 0, y = 0, zoom = 1.0 }

    -- Center on centroid of all projected stations
    local sum_x, sum_y, count = 0, 0, 0
    for _, s in pairs(self.stations) do
        sum_x = sum_x + s.x
        sum_y = sum_y + s.y
        count = count + 1
    end
    if count > 0 then
        self.cam.x = sum_x / count
        self.cam.y = sum_y / count
    end

    -- 8. Pan (drag) state
    self._drag = false
    self._drag_start = { sx = 0, sy = 0, cx = 0, cy = 0 }
end

function SubwayScene:update(dt)
    -- Advance the simulation clock, spawn/move trains, board passengers
    self.scheduler:update(dt, self.network.stations)

    -- Update passenger flow (crowd levels at stations)
    local t = self.scheduler:get_sim_time()
    local dt_minutes = dt * self.scheduler.sim_speed / 60
    self.flow:update(dt_minutes, t.hour, t.day_of_week, self.network.stations)
    -- No separate crowd-sync needed: self.stations IS self.network.stations,
    -- so scheduler and flow already mutate the same station objects.
end

function SubwayScene:draw()
    -- Apply manual camera transform over the 1080-wide map area
    love.graphics.push()
    love.graphics.translate(540, 360)   -- centre of map area (1080/2, 720/2)
    love.graphics.scale(self.cam.zoom)
    love.graphics.translate(-self.cam.x, -self.cam.y)

    self.map:draw_background()
    self.map:draw_lines(self.network, self.network.stations)

    -- Compute canvas-space mouse position for hover highlighting
    local mx, my = self:_screen_to_canvas(love.mouse.getPosition())
    self.map:draw_stations(self.stations, mx, my)
    self.map:draw_trains(self.scheduler.active_trains)

    love.graphics.pop()

    -- Sidebar and HUD are drawn in screen space (no camera)
    self.editor:draw()
    self:_draw_hud()
end

-- Convert screen pixel → canvas pixel (inverse of the camera transform in draw())
function SubwayScene:_screen_to_canvas(sx, sy)
    local cx = (sx - 540) / self.cam.zoom + self.cam.x
    local cy = (sy - 360) / self.cam.zoom + self.cam.y
    return cx, cy
end

function SubwayScene:_draw_hud()
    local t = self.scheduler:get_sim_time()
    local days = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
    local day_name = days[t.day_of_week] or "?"
    local time_str  = string.format("%s %02d:%02d", day_name, t.hour, t.minute)
    local speed_str = string.format("Speed: %dx", math.floor(self.scheduler.sim_speed / 60))

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 8, 8, 160, 44)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(time_str, 14, 14)
    love.graphics.print(speed_str, 14, 32)
end

-- ── Love2D input callbacks (forwarded from main.lua) ─────────────────────────

function SubwayScene:mousepressed(x, y, button)
    local consumed = self.editor:mousepressed(x, y, button, self.cam)
    if not consumed and button == 1 and x < 1080 then
        self._drag = true
        self._drag_start = { sx = x, sy = y, cx = self.cam.x, cy = self.cam.y }
    end
end

function SubwayScene:mousereleased(x, y, button)
    if button == 1 then
        self._drag = false
    end
end

function SubwayScene:mousemoved(x, y, dx, dy)
    self.editor:mousemoved(x, y, self.cam)
    if self._drag then
        -- Use absolute positions relative to drag start to avoid drift
        self.cam.x = self._drag_start.cx - (x - self._drag_start.sx) / self.cam.zoom
        self.cam.y = self._drag_start.cy - (y - self._drag_start.sy) / self.cam.zoom
    end
end

function SubwayScene:wheelmoved(x, y)
    if love.mouse.getX() < 1080 then
        -- Zoom toward/away; keep it simple (no cursor-centre compensation)
        self.cam.zoom = math.max(0.5, math.min(4.0, self.cam.zoom * (1.1 ^ y)))
    else
        self.editor:wheelmoved(y)
    end
end

function SubwayScene:keypressed(key)
    if self.editor:keypressed(key) then return end
    if key == "=" or key == "+" then
        self.scheduler:set_speed(self.scheduler.sim_speed * 2)
    elseif key == "-" then
        self.scheduler:set_speed(math.max(60, self.scheduler.sim_speed / 2))
    end
    -- "escape" is handled by main.lua (quit); do not intercept it here
end

return SubwayScene
