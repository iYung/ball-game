local Scene        = require("lua/core/scene")
local PuzzleLoader = require("lua/game/puzzle_loader")
local UI           = require("lua/core/ui")

local W, H = 1280, 720

-- Grid layout constants (match matrix_scene for identical rendering)
local GRID_X    = 95
local GRID_Y    = 20
local CELL_SIZE = 63
local HUD_X     = 820

local PAUSE_AT_END = 0.6  -- seconds to hold at the last frame before looping

local SolutionRecapScene = setmetatable({}, { __index = Scene })
SolutionRecapScene.__index = SolutionRecapScene

local OP_SYMBOLS = {
    transpose  = "T",
    scale_row  = "xRn",
    swap_rows  = "<>R",
    negate     = "-I",
    scalar_mul = "xk",
    add_matrix = "+M",
    sub_matrix = "-M",
    mul_matrix = "xM",
    set_row    = "=R",
}

local function cell_top_left(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE,
           GRID_Y + (cy - 1) * CELL_SIZE
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Recap buttons (right panel, below the PIECES label). Fixed layout constants.
local RECAP_BUTTONS = {
    { id = "recap:next",   label = "Next puzzle", hint = "[Enter]", rect = { x = 850,  y = 600, w = 150, h = 44 }, color_fill = {0.12,0.28,0.12}, color_border = {0.30,0.75,0.30} },
    { id = "recap:replay", label = "Replay",      hint = "[R]",     rect = { x = 1015, y = 600, w = 110, h = 44 }, color_fill = {0.28,0.20,0.06}, color_border = {0.85,0.65,0.20} },
    { id = "recap:menu",   label = "Menu",        hint = "[Esc]",   rect = { x = 1140, y = 600, w = 110, h = 44 }, color_fill = {0.12,0.15,0.28}, color_border = {0.35,0.45,0.72} },
}

-- ── Constructor ──────────────────────────────────────────────────────────────

function SolutionRecapScene.new(stats, board, frames, run_speed, scene_manager, settings_state)
    local base = Scene.new(W, H)
    local self = setmetatable(base, SolutionRecapScene)
    self._stats          = stats
    self._board          = board
    self._frames         = frames
    self._run_speed      = run_speed or 0.35
    self._scene_manager  = scene_manager
    self._settings_state = settings_state
    self._frame_idx      = 1
    self._anim_t         = 0
    self._end_hold       = 0   -- counts down when we're paused at the last frame
    self._holding        = false
    return self
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function SolutionRecapScene:on_enter()
    local Progress = require("lua/game/progress")
    Progress.mark_solved(self._stats.puzzle_index)

    self._font_title  = love.graphics.newFont(36)
    self._font_stat   = love.graphics.newFont(64)
    self._font_label  = love.graphics.newFont(16)
    self._font_hint   = love.graphics.newFont(14)
    self._font_cell   = love.graphics.newFont(14)
    self._font_ui     = love.graphics.newFont(11)
    self._puzzle_count = PuzzleLoader.count()
end

function SolutionRecapScene:on_exit()
    self.drawer:clear()
end

-- ── Update ───────────────────────────────────────────────────────────────────

function SolutionRecapScene:update(dt)
    local frames = self._frames
    if #frames == 0 then return end

    if self._holding then
        self._end_hold = self._end_hold - dt
        if self._end_hold <= 0 then
            self._holding   = false
            self._frame_idx = 1
            self._anim_t    = 0
        end
        return
    end

    self._anim_t = self._anim_t + dt / self._run_speed
    if self._anim_t >= 1 then
        self._anim_t = 0
        self._frame_idx = self._frame_idx + 1
        if self._frame_idx > #frames then
            self._frame_idx = #frames
            self._anim_t    = 1
            self._holding   = true
            self._end_hold  = PAUSE_AT_END
        end
    end
end

-- ── Draw helpers ─────────────────────────────────────────────────────────────

function SolutionRecapScene:_draw_grid()
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, H)

    local grid = self._board.grid
    for cy = 1, grid.h do
        for cx = 1, grid.w do
            local sx, sy = cell_top_left(cx, cy)
            if (cx + cy) % 2 == 0 then
                love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)

            local tile_raw = grid.cells[cy][cx]
            if tile_raw and tile_raw.kind == "gap" then
                love.graphics.setColor(0.04, 0.04, 0.06, 1)
                love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
                love.graphics.setColor(0.3, 0.1, 0.1, 1)
                love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)
            end
        end
    end

    -- Tiles (pushers skipped here; drawn animated by _draw_pushers)
    for cy = 1, grid.h do
        for cx = 1, grid.w do
            local is_r = grid:is_ref(cx, cy)
            if not is_r then
                local tile = grid:get(cx, cy)
                if tile and tile.kind ~= "pusher" then
                    self:_draw_tile(tile, cx, cy)
                end
            end
        end
    end
end

function SolutionRecapScene:_draw_tile(tile, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local mid_y  = sy + cs / 2

    if tile.kind == "source" then
        local span_w = (tile.width  or 1) * cs
        local span_h = (tile.height or 1) * cs
        love.graphics.setColor(0.1, 0.5, 0.2, 0.5)
        love.graphics.rectangle("fill", sx, sy, span_w, span_h)
        love.graphics.setColor(0.4, 1.0, 0.5, 1)
        love.graphics.setFont(self._font_cell)
        love.graphics.printf("SRC", sx, sy + span_h / 2 - 7, span_w, "center")

    elseif tile.kind == "sink" then
        love.graphics.setColor(0.1, 0.3, 0.7, 0.5)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.5, 0.75, 1.0, 1)
        love.graphics.setFont(self._font_cell)
        love.graphics.printf("SINK", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "pusher" then
        love.graphics.setColor(0.30, 0.18, 0.45, 0.6)
        love.graphics.rectangle("fill", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
        love.graphics.setColor(0.80, 0.60, 1.0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self._font_cell)
        love.graphics.setColor(0.80, 0.60, 1.0, 0.8)
        love.graphics.printf(string.char(64 + (tile.id or 1)), sx, mid_y - 8, cs, "center")

    elseif tile.kind == "op" then
        local w = (tile.width  or 1)
        local h = (tile.height or 1)
        love.graphics.setColor(0.22, 0.14, 0.03, 0.92)
        love.graphics.rectangle("fill", sx, sy, w * cs, h * cs)
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx + 1, sy + 1, w * cs - 2, h * cs - 2)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self._font_cell)
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.printf(OP_SYMBOLS[tile.op] or "?", sx, sy + h * cs / 2 - 8, w * cs, "center")

    elseif tile.kind == "gap" then
        love.graphics.setColor(0.5, 0.15, 0.15, 1)
        love.graphics.setFont(self._font_cell)
        love.graphics.printf("×", sx, mid_y - 8, cs, "center")
    end
end

function SolutionRecapScene:_draw_matrix()
    local frames = self._frames
    if #frames == 0 then return end

    local frame = frames[self._frame_idx]
    local t  = self._anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local px = lerp(frame.from_x, frame.to_x, et)
    local py = lerp(frame.from_y, frame.to_y, et)
    local mat = frame.matrix

    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local cx = px + (c - 1) * CELL_SIZE
            local cy = py + (r - 1) * CELL_SIZE
            local v  = mat.values[r][c]

            love.graphics.setColor(0.08, 0.08, 0.16, 0.92)
            love.graphics.rectangle("fill", cx, cy, CELL_SIZE, CELL_SIZE)

            love.graphics.setColor(1, 0.80, 0.15, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx+1, cy+1, CELL_SIZE-2, CELL_SIZE-2)
            love.graphics.setLineWidth(1)

            local s
            if v == math.floor(v) then s = tostring(math.floor(v))
            else s = string.format("%.1f", v) end
            love.graphics.setColor(0.95, 0.95, 1.0, 1)
            love.graphics.setFont(self._font_cell)
            love.graphics.printf(s, cx, cy + CELL_SIZE / 2 - 9, CELL_SIZE, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function SolutionRecapScene:_draw_pushers()
    local frames = self._frames
    if #frames == 0 then return end
    local frame = frames[self._frame_idx]
    if not frame.pushers_from then return end

    local t  = self._anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local cs = CELL_SIZE

    for i, pf in ipairs(frame.pushers_from) do
        local pt = frame.pushers_to and frame.pushers_to[i]
        local sx = pt and lerp(pf.px, pt.px, et) or pf.px
        local sy = pt and lerp(pf.py, pt.py, et) or pf.py

        love.graphics.setColor(0.30, 0.18, 0.45, 0.6)
        love.graphics.rectangle("fill", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
        love.graphics.setColor(0.80, 0.60, 1.0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self._font_cell)
        love.graphics.setColor(0.80, 0.60, 1.0, 0.8)
        love.graphics.printf(string.char(64 + (pf.id or 1)), sx, sy + cs / 2 - 8, cs, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function SolutionRecapScene:_draw_stats()
    -- Right panel background
    love.graphics.setColor(0.07, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", HUD_X, 0, W - HUD_X, H)

    local panel_w = W - HUD_X
    local cx = HUD_X

    -- Puzzle name
    love.graphics.setFont(self._font_label)
    love.graphics.setColor(0.45, 0.50, 0.70, 1)
    love.graphics.printf(
        string.format("PUZZLE %d — %s", self._stats.puzzle_index, (self._stats.puzzle_name or ""):upper()),
        cx, 36, panel_w, "center"
    )

    -- SOLVED!
    love.graphics.setFont(self._font_title)
    love.graphics.setColor(0.95, 0.85, 0.3, 1)
    love.graphics.printf("SOLVED!", cx, 90, panel_w, "center")

    -- Divider
    love.graphics.setColor(0.25, 0.28, 0.42, 1)
    love.graphics.rectangle("fill", cx + 30, 158, panel_w - 60, 1)

    -- Ticks stat
    love.graphics.setFont(self._font_stat)
    love.graphics.setColor(0.65, 0.85, 1.0, 1)
    love.graphics.printf(tostring(self._stats.ticks), cx, 190, panel_w, "center")
    love.graphics.setFont(self._font_label)
    love.graphics.setColor(0.45, 0.60, 0.80, 1)
    love.graphics.printf("TICKS", cx, 275, panel_w, "center")

    -- Spacer line
    love.graphics.setColor(0.25, 0.28, 0.42, 1)
    love.graphics.rectangle("fill", cx + 60, 320, panel_w - 120, 1)

    -- Pieces stat
    love.graphics.setFont(self._font_stat)
    love.graphics.setColor(0.85, 0.75, 1.0, 1)
    love.graphics.printf(tostring(self._stats.pieces), cx, 350, panel_w, "center")
    love.graphics.setFont(self._font_label)
    love.graphics.setColor(0.60, 0.50, 0.80, 1)
    love.graphics.printf("PIECES", cx, 435, panel_w, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function SolutionRecapScene:_draw_buttons()
    local meta = {}
    for _, b in ipairs(RECAP_BUTTONS) do meta[b.id] = b end

    for _, e in ipairs(self:ui_elements()) do
        local r  = e.rect
        local b  = meta[e.id] or {}
        local cf = b.color_fill   or {0.18, 0.22, 0.36}
        local cb = b.color_border or {0.45, 0.55, 0.85}
        love.graphics.setColor(cf[1], cf[2], cf[3], 1)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(cb[1], cb[2], cb[3], 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setFont(self._font_label)
        love.graphics.setColor(0.90, 0.92, 1.0, 1)
        love.graphics.printf(e.label, r.x, r.y + r.h / 2 - 9, r.w, "center")
        love.graphics.setFont(self._font_hint)
        love.graphics.setColor(0.35, 0.40, 0.55, 1)
        love.graphics.printf(b.hint or "", r.x, r.y + r.h + 6, r.w, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function SolutionRecapScene:draw()
    self:_draw_grid()
    self:_draw_pushers()
    self:_draw_matrix()
    self:_draw_stats()
    self:_draw_buttons()
end

-- ── UI registry ───────────────────────────────────────────────────────────────

function SolutionRecapScene:ui_elements()
    local out = {}
    for _, b in ipairs(RECAP_BUTTONS) do
        out[#out + 1] = {
            id      = b.id,
            label   = b.label,
            kind    = "button",
            rect    = { x = b.rect.x, y = b.rect.y, w = b.rect.w, h = b.rect.h },
            enabled = true,
        }
    end
    return out
end

-- ── Input ─────────────────────────────────────────────────────────────────────

function SolutionRecapScene:_next()
    local next_idx = (self._stats.puzzle_index % self._puzzle_count) + 1
    local MatrixScene = require("lua/game/scenes/matrix_scene")
    self._scene_manager:switch(MatrixScene.new(next_idx, self._scene_manager, self._settings_state))
end

function SolutionRecapScene:_replay()
    self._frame_idx = 1
    self._anim_t    = 0
    self._holding   = false
    self._end_hold  = 0
end

function SolutionRecapScene:_menu()
    local LevelSelectScene = require("lua/game/scenes/level_select_scene")
    self._scene_manager:switch(LevelSelectScene.new(self._scene_manager, self._settings_state))
end

local ACTIONS = {
    ["recap:next"]   = SolutionRecapScene._next,
    ["recap:replay"] = SolutionRecapScene._replay,
    ["recap:menu"]   = SolutionRecapScene._menu,
}

function SolutionRecapScene:key_pressed(key)
    if key == "return" then
        self:_next()
    elseif key == "r" then
        self:_replay()
    elseif key == "escape" then
        self:_menu()
    end
end

-- Left click on a recap button runs its action; any other click does nothing.
function SolutionRecapScene:mouse_pressed(mx, my, btn)
    if btn ~= 1 then return end
    local e = UI.element_at(self:ui_elements(), mx, my)
    if e and e.enabled and ACTIONS[e.id] then
        ACTIONS[e.id](self)
    end
end

function SolutionRecapScene:text_input(_) end

return SolutionRecapScene
