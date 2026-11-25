local Scene        = require("lua/core/scene")
local PuzzleLoader = require("lua/game/puzzle_loader")
local Progress     = require("lua/game/progress")
local UI           = require("lua/core/ui")
local SettingsMenu = require("lua/game/scenes/settings_menu")

local W, H        = 1280, 720
local ROW_H       = 54
local LIST_TOP    = 110
local LIST_LEFT   = 400
local LIST_W      = 480

local TAB_H       = 48

local LevelSelectScene = setmetatable({}, { __index = Scene })
LevelSelectScene.__index = LevelSelectScene

function LevelSelectScene.new(scene_manager, settings_state)
    local self           = Scene.new(W, H)
    setmetatable(self, LevelSelectScene)
    self.scene_manager   = scene_manager
    self._settings_state = settings_state
    self.selected        = 1
    self._world          = 1
    self._world_puzzles  = {}
    self._row_rects      = {}
    self._tab_rects      = {}
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

    -- Tab rects: one per world, evenly spaced across full width
    local n = PuzzleLoader.world_count()
    local tab_w = W / n
    self._tab_rects = {}
    for w = 1, n do
        self._tab_rects[w] = { x = (w - 1) * tab_w, y = 0, w = tab_w, h = TAB_H }
    end
end

function LevelSelectScene:on_enter()
    self._font_title    = love.graphics.newFont(28)
    self._font_world    = love.graphics.newFont(14)
    self._font_row      = love.graphics.newFont(20)
    self._font_hint     = love.graphics.newFont(14)
    self._settings_menu = SettingsMenu.new(self._settings_state, self.scene_manager)
    local Sound = require("lua/core/sound")
    if not Sound.is_music_playing("menu") then Sound.play_music("menu") end

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
    self:_switch_world(candidate)
end

function LevelSelectScene:_switch_world(target)
    self._world = target

    local cs_path = string.format("data/cutscenes/world_%d.lua", self._world)
    if self._world ~= 1
        and love.filesystem.getInfo(cs_path)
        and not Progress.is_cutscene_seen(self._world)
    then
        Progress.mark_cutscene_seen(self._world)
        local CutsceneScene    = require("lua/game/scenes/cutscene_scene")
        local LevelSelectScene = require("lua/game/scenes/level_select_scene")
        local next_scene       = LevelSelectScene.new(self.scene_manager, self._settings_state)
        next_scene._world      = self._world
        self.scene_manager:switch(CutsceneScene.new(self._world, next_scene, self.scene_manager))
        return
    end

    self.selected = 1
    self:_rebuild_world_data()
end

-- Builds the base level-select elements (tabs + puzzle rows) without delegating
-- to the settings overlay. Used by draw() so tabs/rows render correctly even
-- when the settings overlay is open on top.
function LevelSelectScene:_base_elements()
    local els = {}
    local n = PuzzleLoader.world_count()
    for w = 1, n do
        local unlocked = Progress.is_world_unlocked(w)
        local world_data = PuzzleLoader.world(w)
        local label = unlocked and world_data.name or "[?]"
        local r = self._tab_rects[w] or { x = 0, y = 0, w = 0, h = 0 }
        els[#els + 1] = {
            id       = "world:" .. w,
            label    = label,
            kind     = "button",
            rect     = { x = r.x, y = r.y, w = r.w, h = r.h },
            enabled  = unlocked,
            selected = (w == self._world),
        }
    end
    for i, puzzle in ipairs(self._world_puzzles) do
        local r = self._row_rects[i]
        els[#els + 1] = { id = "puzzle:" .. puzzle.index, label = puzzle.name, kind = "button",
                          rect = { x = r.x, y = r.y, w = r.w, h = r.h }, enabled = true,
                          selected = (i == self.selected) }
    end
    return els
end

-- Registry of clickable elements: one tab per world, then one row per puzzle.
function LevelSelectScene:ui_elements()
    if self._settings_menu and self._settings_menu.is_open then
        return self._settings_menu:ui_elements()
    end
    return self:_base_elements()
end

-- Row number (1-based) of a puzzle element, or nil for other elements.
function LevelSelectScene:_row_of(e)
    if not e then return nil end
    for i, puzzle in ipairs(self._world_puzzles) do
        if e.id == "puzzle:" .. puzzle.index then return i end
    end
    return nil
end

-- World index from a world:N element id, or nil.
local function world_index_of(e)
    if not e then return nil end
    local w = e.id:match("^world:(%d+)$")
    return w and tonumber(w) or nil
end

function LevelSelectScene:update(_dt)
    if self._settings_menu and self._settings_menu.is_open then
        self._settings_menu:update(_dt)
    end
end

function LevelSelectScene:mouse_moved(x, y)
    local row = self:_row_of(UI.element_at(self:ui_elements(), x, y))
    if row then
        self.selected = row
    end
end

function LevelSelectScene:_load_selected()
    local MatrixScene = require("lua/game/scenes/matrix_scene")
    local puzzle_index = self._world_puzzles[self.selected].index
    self.scene_manager:switch(MatrixScene.new(puzzle_index, self.scene_manager, self._settings_state))
end

function LevelSelectScene:key_pressed(key)
    if self._settings_menu and self._settings_menu.is_open then
        if self._settings_menu:key_pressed(key) then return end
    end

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
        if self._settings_menu then
            self._settings_menu:open()
        end
    end
end

function LevelSelectScene:mouse_pressed(mx, my, btn)
    if self._settings_menu and self._settings_menu.is_open then
        self._settings_menu:mouse_pressed(mx, my)
        return
    end
    if btn ~= 1 then return end
    local e = UI.element_at(self:ui_elements(), mx, my)
    if not e then return end
    local wi = world_index_of(e)
    if wi and e.enabled then
        self:_switch_world(wi)
    elseif self:_row_of(e) then
        self.selected = self:_row_of(e)
        self:_load_selected()
    end
end

function LevelSelectScene:draw()
    -- Background
    love.graphics.setColor(0.07, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Tab bar background
    love.graphics.setColor(0.09, 0.10, 0.17, 1)
    love.graphics.rectangle("fill", 0, 0, W, TAB_H)

    -- Tabs (use base elements so rects stay correct even when settings overlay is open)
    local elements = self:_base_elements()
    love.graphics.setFont(self._font_world)
    local n_worlds = PuzzleLoader.world_count()
    for w = 1, n_worlds do
        local e = UI.find(elements, "world:" .. w)
        local r = e.rect
        local is_active   = e.selected
        local is_unlocked = e.enabled

        if is_active then
            love.graphics.setColor(0.14, 0.16, 0.28, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
            -- Bottom underline
            love.graphics.setColor(0.45, 0.60, 1.0, 1)
            love.graphics.rectangle("fill", r.x + 2, r.y + r.h - 4, r.w - 4, 4)
        end

        -- Tab separator line
        if w < n_worlds then
            love.graphics.setColor(0.20, 0.22, 0.35, 1)
            love.graphics.rectangle("fill", r.x + r.w - 1, r.y + 6, 1, r.h - 12)
        end

        -- Label
        local label_y = r.y + (r.h - self._font_world:getHeight()) / 2
        if not is_unlocked then
            love.graphics.setColor(0.35, 0.28, 0.35, 1)
        elseif is_active then
            love.graphics.setColor(0.90, 0.92, 1.0, 1)
        else
            love.graphics.setColor(0.50, 0.55, 0.75, 1)
        end
        love.graphics.printf(e.label, r.x, label_y, r.w, "center")
    end

    -- Title
    love.graphics.setFont(self._font_world)
    love.graphics.setColor(0.65, 0.75, 1.0, 1)
    love.graphics.printf("SELECT PUZZLE", 0, TAB_H + 8, W, "center")

    -- Rows
    love.graphics.setFont(self._font_row)
    for _, puzzle in ipairs(self._world_puzzles) do
        local e   = UI.find(elements, "puzzle:" .. puzzle.index)
        local r   = e.rect
        local sel = e.selected

        if sel then
            love.graphics.setColor(0.35, 0.45, 0.80, 1)
            love.graphics.rectangle("fill", r.x, r.y + 4, 4, r.h - 8)
            love.graphics.setColor(0.14, 0.16, 0.26, 1)
            love.graphics.rectangle("fill", r.x + 8, r.y + 2, r.w - 8, r.h - 4, 4, 4)
            love.graphics.setColor(0.35, 0.45, 0.80, 1)
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

    if self._settings_menu then
        self._settings_menu:draw()
    end
end

function LevelSelectScene:text_input(_) end

return LevelSelectScene
