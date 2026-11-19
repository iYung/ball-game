local Scene        = require("lua/core/scene")
local PuzzleLoader = require("game/puzzle_loader")

local W, H        = 1280, 720
local ROW_H       = 54
local LIST_TOP    = 140
local LIST_LEFT   = 400
local LIST_W      = 480

local LevelSelectScene = setmetatable({}, { __index = Scene })
LevelSelectScene.__index = LevelSelectScene

function LevelSelectScene.new(scene_manager)
    local self          = Scene.new(W, H)
    setmetatable(self, LevelSelectScene)
    self.scene_manager  = scene_manager
    self.selected       = 1
    self._names         = {}
    self._row_rects     = {}
    return self
end

function LevelSelectScene:on_enter()
    self._font_title = love.graphics.newFont(28)
    self._font_row   = love.graphics.newFont(20)
    self._font_hint  = love.graphics.newFont(14)

    self._names = {}
    for i = 1, PuzzleLoader.count() do
        self._names[i] = PuzzleLoader.load(i).name or ("Puzzle " .. i)
    end

    self._row_rects = {}
    for i = 1, #self._names do
        self._row_rects[i] = {
            x = LIST_LEFT,
            y = LIST_TOP + (i - 1) * ROW_H,
            w = LIST_W,
            h = ROW_H,
        }
    end
end

local function _row_at(rects, lx, ly)
    for i, r in ipairs(rects) do
        if lx >= r.x and lx < r.x + r.w and ly >= r.y and ly < r.y + r.h then
            return i
        end
    end
    return nil
end

local function _logical_mouse()
    local scale = math.min(love.graphics.getWidth() / W, love.graphics.getHeight() / H)
    local ox    = (love.graphics.getWidth()  - W * scale) / 2
    local oy    = (love.graphics.getHeight() - H * scale) / 2
    return (love.mouse.getX() - ox) / scale,
           (love.mouse.getY() - oy) / scale
end

function LevelSelectScene:update(_dt)
    local lx, ly = _logical_mouse()
    local hovered = _row_at(self._row_rects, lx, ly)
    if hovered then
        self.selected = hovered
    end
end

function LevelSelectScene:_load_selected()
    local MatrixScene = require("game/scenes/matrix_scene")
    self.scene_manager:switch(MatrixScene.new(self.selected, self.scene_manager))
end

function LevelSelectScene:key_pressed(key)
    local n = #self._names
    if key == "up" then
        self.selected = ((self.selected - 2) % n) + 1
    elseif key == "down" then
        self.selected = (self.selected % n) + 1
    elseif key == "return" or key == "space" then
        self:_load_selected()
    elseif key == "escape" then
        local StartScene = require("game/scenes/start_scene")
        self.scene_manager:switch(StartScene.new(self.scene_manager))
    end
end

function LevelSelectScene:mouse_pressed(mx, my, btn)
    if btn ~= 1 then return end
    local hit = _row_at(self._row_rects, mx, my)
    if hit then
        self.selected = hit
        self:_load_selected()
    end
end

function LevelSelectScene:draw()
    -- Background
    love.graphics.setColor(0.07, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title
    love.graphics.setFont(self._font_title)
    love.graphics.setColor(0.65, 0.75, 1.0, 1)
    love.graphics.printf("SELECT PUZZLE", 0, 60, W, "center")

    -- Rows
    love.graphics.setFont(self._font_row)
    for i, name in ipairs(self._names) do
        local r   = self._row_rects[i]
        local sel = (i == self.selected)

        if sel then
            -- Accent bar on left
            love.graphics.setColor(0.35, 0.45, 0.80, 1)
            love.graphics.rectangle("fill", r.x, r.y + 4, 4, r.h - 8)
            -- Row highlight
            love.graphics.setColor(0.14, 0.16, 0.26, 1)
            love.graphics.rectangle("fill", r.x + 8, r.y + 2, r.w - 8, r.h - 4, 4, 4)
            love.graphics.setColor(0.35, 0.45, 0.80, 0.6)
            love.graphics.rectangle("line", r.x + 8, r.y + 2, r.w - 8, r.h - 4, 4, 4)
        end

        -- Index number
        local num_w = 44
        if sel then
            love.graphics.setColor(0.60, 0.75, 1.0, 1)
        else
            love.graphics.setColor(0.35, 0.40, 0.55, 1)
        end
        love.graphics.printf(string.format("%02d", i), r.x + 16, r.y + (r.h - self._font_row:getHeight()) / 2, num_w, "left")

        -- Puzzle name
        if sel then
            love.graphics.setColor(0.90, 0.92, 1.0, 1)
        else
            love.graphics.setColor(0.50, 0.55, 0.70, 1)
        end
        love.graphics.printf(name, r.x + 16 + num_w, r.y + (r.h - self._font_row:getHeight()) / 2, r.w - 16 - num_w, "left")
    end

    -- Hint
    love.graphics.setFont(self._font_hint)
    love.graphics.setColor(0.35, 0.40, 0.55, 1)
    love.graphics.printf("[↑↓] Navigate   [Enter] Play   [Esc] Back", 0, H - 36, W, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function LevelSelectScene:text_input(_) end

return LevelSelectScene
