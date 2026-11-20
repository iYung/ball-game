local Scene        = require("lua/core/scene")
local PuzzleLoader = require("lua/game/puzzle_loader")
local Progress     = require("lua/game/progress")
local UI           = require("lua/core/ui")

local W, H        = 1280, 720
local ROW_H       = 54
local LIST_TOP    = 190
local LIST_LEFT   = 400
local LIST_W      = 480

local BAR_Y       = 100
local BAR_H       = 50
local ARROW_W     = 48

local LevelSelectScene = setmetatable({}, { __index = Scene })
LevelSelectScene.__index = LevelSelectScene

function LevelSelectScene.new(scene_manager)
    local self          = Scene.new(W, H)
    setmetatable(self, LevelSelectScene)
    self.scene_manager  = scene_manager
    self.selected       = 1
    self._world         = 1
    self._world_puzzles = {}
    self._row_rects     = {}
    self._arrow_left    = {}
    self._arrow_right   = {}
    return self
end

function LevelSelectScene:_rebuild_world_data()
    local world = PuzzleLoader.world(self._world)
    self._world_puzzles = world.puzzles

    self._row_rects = {}
    for i = 1, #self._world_puzzles do
        self._row_rects[i] = {
            x = LIST_LEFT,
            y = LIST_TOP + (i - 1) * ROW_H,
            w = LIST_W,
            h = ROW_H,
        }
    end

    -- Arrow hit rects centered in the bar
    local bar_cx = W / 2
    local name_w = 320
    self._arrow_left  = { x = bar_cx - name_w / 2 - ARROW_W - 8, y = BAR_Y, w = ARROW_W, h = BAR_H }
    self._arrow_right = { x = bar_cx + name_w / 2 + 8,            y = BAR_Y, w = ARROW_W, h = BAR_H }
end

function LevelSelectScene:on_enter()
    self._font_title = love.graphics.newFont(28)
    self._font_world = love.graphics.newFont(22)
    self._font_row   = love.graphics.newFont(20)
    self._font_hint  = love.graphics.newFont(14)

    self:_rebuild_world_data()
end

function LevelSelectScene:_cycle_world(delta)
    local n = PuzzleLoader.world_count()
    local candidate = self._world
    for _ = 1, n do
        candidate = ((candidate - 1 + delta) % n) + 1
        if Progress.is_world_unlocked(candidate) then
            break
        end
    end
    self._world = candidate

    local cs_path = string.format("data/cutscenes/world_%d.lua", self._world)
    if self._world ~= 1
        and love.filesystem.getInfo(cs_path)
        and not Progress.is_cutscene_seen(self._world)
    then
        Progress.mark_cutscene_seen(self._world)
        local CutsceneScene    = require("lua/game/scenes/cutscene_scene")
        local LevelSelectScene = require("lua/game/scenes/level_select_scene")
        local next_scene       = LevelSelectScene.new(self.scene_manager)
        next_scene._world      = self._world
        self.scene_manager:switch(CutsceneScene.new(self._world, next_scene, self.scene_manager))
        return
    end

    self.selected = 1
    self:_rebuild_world_data()
end

-- Registry of clickable elements (see docs/design/ui-tests.md section 2):
-- world arrows first, then one row per puzzle in row order.
function LevelSelectScene:ui_elements()
    local els = {}
    local function rect(r) return { x = r.x, y = r.y, w = r.w, h = r.h } end
    if self._arrow_left.x then
        els[#els + 1] = { id = "world:prev", label = "<", kind = "button",
                          rect = rect(self._arrow_left), enabled = true }
        els[#els + 1] = { id = "world:next", label = ">", kind = "button",
                          rect = rect(self._arrow_right), enabled = true }
    end
    for i, puzzle in ipairs(self._world_puzzles) do
        els[#els + 1] = { id = "puzzle:" .. puzzle.index, label = puzzle.name, kind = "button",
                          rect = rect(self._row_rects[i]), enabled = true,
                          selected = (i == self.selected) }
    end
    return els
end

-- Row number (1-based) of a puzzle element, or nil for other elements.
function LevelSelectScene:_row_of(e)
    if not e then return nil end
    for i, puzzle in ipairs(self._world_puzzles) do
        if e.id == "puzzle:" .. puzzle.index then return i end
    end
    return nil
end

-- Hover only changes the selection when the mouse actually moves, so a
-- resting cursor never overrides Up/Down navigation.
function LevelSelectScene:update(_dt) end

function LevelSelectScene:mouse_moved(x, y)
    local row = self:_row_of(UI.element_at(self:ui_elements(), x, y))
    if row then
        self.selected = row
    end
end

function LevelSelectScene:_load_selected()
    local MatrixScene = require("lua/game/scenes/matrix_scene")
    local puzzle_index = self._world_puzzles[self.selected].index
    self.scene_manager:switch(MatrixScene.new(puzzle_index, self.scene_manager))
end

function LevelSelectScene:key_pressed(key)
    local n = #self._world_puzzles
    if key == "up" then
        self.selected = ((self.selected - 2) % n) + 1
    elseif key == "down" then
        self.selected = (self.selected % n) + 1
    elseif key == "left" then
        self:_cycle_world(-1)
    elseif key == "right" then
        self:_cycle_world(1)
    elseif key == "return" or key == "space" then
        self:_load_selected()
    elseif key == "u" then
        Progress.unlock_world(self._world)
        self:_rebuild_world_data()
    elseif key == "escape" then
        local StartScene = require("lua/game/scenes/start_scene")
        self.scene_manager:switch(StartScene.new(self.scene_manager))
    end
end

function LevelSelectScene:mouse_pressed(mx, my, btn)
    if btn ~= 1 then return end
    local e = UI.element_at(self:ui_elements(), mx, my)
    if not e then return end
    if e.id == "world:prev" then
        self:_cycle_world(-1)
    elseif e.id == "world:next" then
        self:_cycle_world(1)
    elseif self:_row_of(e) then
        self.selected = self:_row_of(e)
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
    love.graphics.printf("SELECT PUZZLE", 0, 44, W, "center")

    -- World bar
    local world      = PuzzleLoader.world(self._world)
    local world_name = string.format("WORLD %d: %s", self._world, world.name:upper())
    local bar_cx     = W / 2
    local name_w     = 320
    local bar_x      = bar_cx - name_w / 2
    local bar_y      = BAR_Y
    local bar_h      = BAR_H

    -- Bar background
    love.graphics.setColor(0.11, 0.12, 0.20, 1)
    love.graphics.rectangle("fill", bar_x - ARROW_W - 8, bar_y, name_w + (ARROW_W + 8) * 2, bar_h, 6, 6)
    love.graphics.setColor(0.25, 0.32, 0.55, 0.7)
    love.graphics.rectangle("line", bar_x - ARROW_W - 8, bar_y, name_w + (ARROW_W + 8) * 2, bar_h, 6, 6)

    -- Left arrow
    love.graphics.setFont(self._font_world)
    love.graphics.setColor(0.55, 0.65, 0.90, 1)
    love.graphics.printf("<", bar_x - ARROW_W - 8, bar_y + (bar_h - self._font_world:getHeight()) / 2, ARROW_W, "center")

    -- World name
    love.graphics.setColor(0.90, 0.92, 1.0, 1)
    love.graphics.printf(world_name, bar_x, bar_y + (bar_h - self._font_world:getHeight()) / 2, name_w, "center")

    -- Right arrow
    love.graphics.setColor(0.55, 0.65, 0.90, 1)
    love.graphics.printf(">", bar_cx + name_w / 2 + 8, bar_y + (bar_h - self._font_world:getHeight()) / 2, ARROW_W, "center")

    -- World dots
    local n_worlds = PuzzleLoader.world_count()
    local dot_r    = 4
    local dot_gap  = 14
    local dots_w   = n_worlds * dot_gap - (dot_gap - dot_r * 2)
    local dot_y    = bar_y + bar_h + 10
    local dot_x0   = bar_cx - dots_w / 2
    for w = 1, n_worlds do
        if w == self._world then
            love.graphics.setColor(0.55, 0.65, 0.90, 1)
        elseif not Progress.is_world_unlocked(w) then
            love.graphics.setColor(0.30, 0.22, 0.28, 1)
        else
            love.graphics.setColor(0.25, 0.30, 0.45, 1)
        end
        love.graphics.circle("fill", dot_x0 + (w - 1) * dot_gap + dot_r, dot_y + dot_r, dot_r)
    end

    -- Rows
    love.graphics.setFont(self._font_row)
    local elements = self:ui_elements()
    for _, puzzle in ipairs(self._world_puzzles) do
        local e   = UI.find(elements, "puzzle:" .. puzzle.index)
        local r   = e.rect
        local sel = e.selected

        if sel then
            love.graphics.setColor(0.35, 0.45, 0.80, 1)
            love.graphics.rectangle("fill", r.x, r.y + 4, 4, r.h - 8)
            love.graphics.setColor(0.14, 0.16, 0.26, 1)
            love.graphics.rectangle("fill", r.x + 8, r.y + 2, r.w - 8, r.h - 4, 4, 4)
            love.graphics.setColor(0.35, 0.45, 0.80, 0.6)
            love.graphics.rectangle("line", r.x + 8, r.y + 2, r.w - 8, r.h - 4, 4, 4)
        end

        local num_w = 44
        if sel then
            love.graphics.setColor(0.60, 0.75, 1.0, 1)
        else
            love.graphics.setColor(0.35, 0.40, 0.55, 1)
        end
        love.graphics.printf(string.format("%02d", puzzle.index), r.x + 16, r.y + (r.h - self._font_row:getHeight()) / 2, num_w, "left")

        if sel then
            love.graphics.setColor(0.90, 0.92, 1.0, 1)
        else
            love.graphics.setColor(0.50, 0.55, 0.70, 1)
        end
        love.graphics.printf(puzzle.name, r.x + 16 + num_w, r.y + (r.h - self._font_row:getHeight()) / 2, r.w - 16 - num_w, "left")
    end

    -- Hint
    love.graphics.setFont(self._font_hint)
    love.graphics.setColor(0.35, 0.40, 0.55, 1)
    love.graphics.printf("[Left/Right] Switch World   [Up/Down] Navigate   [Enter] Play   [Esc] Back", 0, H - 36, W, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function LevelSelectScene:text_input(_) end

return LevelSelectScene
