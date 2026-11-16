local Scene        = require("lua/core/scene")
local Matrix       = require("game/matrix_math")
local Grid         = require("game/grid")
local Cursor       = require("game/cursor")
local Palette      = require("game/palette")
local HUD          = require("game/hud")
local PuzzleLoader = require("game/puzzle_loader")

local function cell_key(x, y) return x .. "," .. y end

local MatrixScene = {}
MatrixScene.__index = MatrixScene

-- Layout constants
local GRID_X     = 95
local GRID_Y     = 20
local CELL_SIZE  = 63
local PALETTE_Y  = 660
local HUD_X      = 820

-- Ops that expose editable parameters
local PARAM_DEFS = {
    scale_row  = { {key="row",    label="row", min=1, max=4},
                   {key="scalar", label="x",   min=-9, max=9} },
    add_rows   = { {key="src",    label="src", min=1, max=4},
                   {key="dst",    label="dst", min=1, max=4},
                   {key="scalar", label="x",   min=-9, max=9} },
    swap_rows  = { {key="row_a",  label="r1",  min=1, max=4},
                   {key="row_b",  label="r2",  min=1, max=4} },
    scalar_mul = { {key="scalar", label="x",   min=-9, max=9} },
}

local DEFAULT_PARAMS = {
    scale_row  = {row=1,  scalar=2},
    add_rows   = {src=1,  dst=2,   scalar=1},
    swap_rows  = {row_a=1, row_b=2},
    scalar_mul = {scalar=2},
}

local OP_SYMBOLS = {
    transpose  = "T",
    scale_row  = "xRn",
    add_rows   = "R+R",
    swap_rows  = "<>R",
    negate     = "-I",
    scalar_mul = "xk",
}

-- How many board cells each op tile spans horizontally.
-- Anchor cell = op symbol; each additional cell = one parameter.
local OP_WIDTHS = {
    transpose  = 1,
    negate     = 1,
    scalar_mul = 2,
    scale_row  = 3,
    swap_rows  = 3,
    add_rows   = 4,
}

local DIR_ARROWS = { right="->", left="<-", up="^", down="v" }

local PALETTE_BUTTONS = {
    { kind="arrow", dir="right",  label="->" },
    { kind="arrow", dir="left",   label="<-" },
    { kind="arrow", dir="up",     label="^"  },
    { kind="arrow", dir="down",   label="v"  },
    { sep=true },
    { kind="op", op="transpose",  label="T"  },
    { kind="op", op="scale_row",  label="xR" },
    { kind="op", op="add_rows",   label="R+R"},
    { kind="op", op="swap_rows",  label="<>R"},
    { kind="op", op="negate",     label="-I" },
    { kind="op", op="scalar_mul", label="xk" },
    { sep=true },
    { erase=true, label="[X]" },
}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function screen_to_cell(mx, my)
    local cx = math.floor((mx - GRID_X) / CELL_SIZE) + 1
    local cy = math.floor((my - GRID_Y) / CELL_SIZE) + 1
    return cx, cy
end

local function cell_top_left(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE,
           GRID_Y + (cy - 1) * CELL_SIZE
end

local function in_grid_panel(mx, my)
    return mx >= GRID_X and mx < GRID_X + 10 * CELL_SIZE
       and my >= GRID_Y and my < GRID_Y + 10 * CELL_SIZE
end

local function lerp(a, b, t) return a + (b - a) * t end

-- ── Constructor ────────────────────────────────────────────────────────────

function MatrixScene.new(puzzle_index)
    local base = Scene.new(1280, 720)
    local self  = setmetatable(base, MatrixScene)
    self._start_puzzle = puzzle_index or 1
    return self
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function MatrixScene:on_enter()
    self.palette      = Palette.new()
    self.hud          = HUD.new(HUD_X, 0, 460, 720)
    self.font_cell    = love.graphics.newFont(14)
    self.font_ui      = love.graphics.newFont(11)
    self.font_key     = love.graphics.newFont(11)
    self.font_val     = love.graphics.newFont(13)
    self.run_speed    = 0.22
    self.anim_from_x  = 0;  self.anim_from_y = 0
    self.anim_to_x    = 0;  self.anim_to_y   = 0
    self.anim_t       = 1
    self.anim_ready   = false

    self._btn_rects = {}
    local bx, by = 10, PALETTE_Y + 6
    local bw, bh, gap = 48, 48, 56
    for i, btn in ipairs(PALETTE_BUTTONS) do
        if btn.sep then
            bx = bx + 20
        else
            self._btn_rects[i] = { x=bx, y=by, w=bw, h=bh, btn=btn }
            bx = bx + gap
        end
    end

    self:load_puzzle(self._start_puzzle)
end

function MatrixScene:on_exit()
    self.drawer:clear()
end

-- ── Puzzle management ──────────────────────────────────────────────────────

function MatrixScene:load_puzzle(n)
    self.puzzle_index   = math.max(1, math.min(n, PuzzleLoader.count()))
    self.puzzle         = PuzzleLoader.load(self.puzzle_index)
    local p             = self.puzzle
    self.input_matrix   = Matrix.new(p.input.rows,  p.input.cols,  p.input.values)
    self.target_matrix  = Matrix.new(p.target.rows, p.target.cols, p.target.values)
    self.current_matrix = nil
    self.status         = nil
    self.running        = false
    self.cursor         = nil
    self.grid           = Grid.new(p.grid_w, p.grid_h)

    if p.locked then
        for _, t in ipairs(p.locked) do
            self.grid:set(t.x, t.y, {
                kind=t.kind, dir=t.dir, op=t.op,
                params=t.params or {}, locked=true,
            })
        end
    end
    self.grid:set(p.source.x, p.source.y, {kind="source", dir=p.source.dir, locked=true})
    self.grid:set(p.sink.x,   p.sink.y,   {kind="sink",   locked=true})
    self.occupied_ops = {}
    self._last_fp     = {}
end

function MatrixScene:do_reset()
    self.current_matrix = nil
    self.status         = nil
    self.running        = false
    self.cursor         = nil
    self.occupied_ops   = {}
    self._last_fp       = {}
    self.anim_t         = 1
    self.anim_ready     = false
end

-- Returns a table keyed by cell_key for every board cell the matrix currently covers.
function MatrixScene:get_footprint()
    local mat  = self.current_matrix
    if not mat or not self.cursor then return {} end
    local cx, cy = self.cursor.x, self.cursor.y
    local fp = {}
    for r = 0, mat.rows - 1 do
        for c = 0, mat.cols - 1 do
            local x, y = cx + c, cy + r
            if self.grid:in_bounds(x, y) then
                fp[cell_key(x, y)] = {x=x, y=y}
            end
        end
    end
    return fp
end

function MatrixScene:_snap_anim_to_cursor()
    if self.cursor then
        local px, py = cell_top_left(self.cursor.x, self.cursor.y)
        self.anim_from_x=px; self.anim_from_y=py
        self.anim_to_x=px;   self.anim_to_y=py
        self.anim_t = 1
    end
end

function MatrixScene:start_run()
    local p             = self.puzzle
    self.current_matrix = self.input_matrix:copy()
    self.cursor         = Cursor.new(self.grid, p.source.x, p.source.y, p.source.dir,
                                     p.sink.x, p.sink.y)
    self.status         = "running"
    self.running        = true
    self.occupied_ops   = {}
    self._last_fp       = {}  -- empty so first move enters all new footprint cells
    self.anim_t         = 1
    self.anim_ready     = true
    self:_snap_anim_to_cursor()
end

function MatrixScene:do_step()
    if not self.cursor then self:start_run(); return end

    local old_fp         = self._last_fp
    local from_x, from_y = cell_top_left(self.cursor.x, self.cursor.y)

    local status = self.cursor:move()

    local to_x, to_y = cell_top_left(self.cursor.x, self.cursor.y)
    local new_fp     = self:get_footprint()
    self._last_fp    = new_fp

    -- Deactivate op tiles whose entire footprint the matrix has fully left.
    for akey, info in pairs(self.occupied_ops) do
        local tile  = self.grid:get(info.ax, info.ay)
        local width = (tile and tile.width) or 1
        local still_covered = false
        for i = 0, width - 1 do
            if new_fp[cell_key(info.ax + i, info.ay)] then
                still_covered = true; break
            end
        end
        if not still_covered then self.occupied_ops[akey] = nil end
    end

    -- Collect newly entered op tiles, deduplicated by anchor position.
    local entered_anchors = {}
    local seen = {}
    for key, cell in pairs(new_fp) do
        if not old_fp[key] then
            local ax, ay = self.grid:get_anchor(cell.x, cell.y)
            local akey = cell_key(ax, ay)
            if not self.occupied_ops[akey] and not seen[akey] then
                seen[akey] = true
                entered_anchors[#entered_anchors+1] = {x=ax, y=ay, akey=akey}
            end
        end
    end
    -- Fire in top-to-bottom, left-to-right order (by anchor position).
    table.sort(entered_anchors, function(a, b)
        return a.y < b.y or (a.y == b.y and a.x < b.x)
    end)

    local mat = self.current_matrix
    for _, info in ipairs(entered_anchors) do
        local tile = self.grid:get(info.x, info.y)
        if tile and tile.kind == "op" then
            mat = Cursor.apply_op(tile, mat)
            self.occupied_ops[info.akey] = {ax=info.x, ay=info.y}
        end
    end
    self.current_matrix = mat

    if status == "sink" then
        self.running = false
        self.status  = mat:equals(self.target_matrix) and "win" or "fail"
        self.anim_from_x=to_x; self.anim_from_y=to_y
        self.anim_to_x=to_x;   self.anim_to_y=to_y
        self.anim_t     = 1
        self.anim_ready = false
    elseif status ~= "ok" then
        self.running = false
        self.status  = status
        self.anim_t  = 1
        self.anim_ready = false
    else
        self.anim_from_x=from_x; self.anim_from_y=from_y
        self.anim_to_x=to_x;     self.anim_to_y=to_y
        self.anim_t     = 0
        self.anim_ready = false
    end
end

-- ── Update ─────────────────────────────────────────────────────────────────

function MatrixScene:update(dt)
    if self.anim_t < 1 then
        self.anim_t = math.min(1, self.anim_t + dt / self.run_speed)
        if self.anim_t >= 1 and self.running then
            self.anim_ready = true
        end
    end
    if self.running and self.anim_ready then
        self.anim_ready = false
        self:do_step()
    end
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

function MatrixScene:draw_grid()
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, PALETTE_Y)

    -- Pass 1: checkerboard backgrounds and grid lines
    for cy = 1, 10 do
        for cx = 1, 10 do
            local sx, sy = cell_top_left(cx, cy)
            if (cx + cy) % 2 == 0 then
                love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)
        end
    end

    -- Pass 2: tile content — anchor cells draw their full span, ref cells draw param content
    for cy = 1, 10 do
        for cx = 1, 10 do
            local is_r, ax, ay = self.grid:is_ref(cx, cy)
            if is_r then
                local anchor_tile = self.grid:get(cx, cy)
                self:draw_param_cell(anchor_tile, cx - ax, cx, cy)
            else
                local tile = self.grid:get(cx, cy)
                if tile then self:draw_tile(tile, cx, cy) end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- draw_tile takes cell coordinates so multi-cell ops can draw a spanning background.
function MatrixScene:draw_tile(tile, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local mid_y  = sy + cs / 2

    if tile.kind == "source" then
        love.graphics.setColor(0.1, 0.5, 0.2, 0.5)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.4, 1.0, 0.5, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("SRC", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "sink" then
        love.graphics.setColor(0.1, 0.3, 0.7, 0.5)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.5, 0.75, 1.0, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("SINK", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "arrow" then
        love.graphics.setColor(0.7, 0.8, 0.5, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf(DIR_ARROWS[tile.dir] or "?", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "op" then
        local width  = tile.width or 1
        local span_w = width * cs
        -- Spanning fill covers all param cells too; drawn here before ref cells run
        love.graphics.setColor(0.22, 0.14, 0.03, 0.92)
        love.graphics.rectangle("fill", sx, sy, span_w, cs)
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx + 1, sy + 1, span_w - 2, cs - 2)
        love.graphics.setLineWidth(1)
        -- Op symbol in the anchor cell
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf(OP_SYMBOLS[tile.op] or "?", sx, mid_y - 8, cs, "center")
    end

    if tile.locked then
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.circle("fill", sx + cs - 8, sy + 7, 3)
        love.graphics.rectangle("fill", sx + cs - 10, sy + 7, 4, 5)
    end
end

-- Draw a parameter cell for a multi-cell op tile.
-- param_index is 1-based (1 = first param of the op).
function MatrixScene:draw_param_cell(tile, param_index, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local defs   = PARAM_DEFS[tile.op]
    if not defs or not defs[param_index] then return end
    local def = defs[param_index]
    local val = tostring((tile.params or {})[def.key] or 0)

    -- Param label
    love.graphics.setColor(0.65, 0.5, 0.15, 1)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf(def.label, sx, sy + 5, cs, "center")

    -- Value
    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(val, sx, sy + cs / 2 - 10, cs, "center")

    -- [-] / [+] affordances in the bottom area; left and right thirds
    love.graphics.setColor(0.55, 0.42, 0.15, 0.9)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

function MatrixScene:draw_travelling_matrix()
    local mat = self.current_matrix
    if not mat then return end

    local t  = self.anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local px = lerp(self.anim_from_x, self.anim_to_x, et)
    local py = lerp(self.anim_from_y, self.anim_to_y, et)

    -- Each matrix element = one board cell
    local bx = px
    local by = py

    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local cx = bx + (c - 1) * CELL_SIZE
            local cy = by + (r - 1) * CELL_SIZE
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
            love.graphics.setFont(self.font_cell)
            love.graphics.printf(s, cx, cy + CELL_SIZE / 2 - 9, CELL_SIZE, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_palette()
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, PALETTE_Y, HUD_X, 60)

    local sel = self.palette:selected()
    for _, rect in pairs(self._btn_rects) do
        local btn    = rect.btn
        local is_sel = false
        if sel == nil and btn.erase then
            is_sel = true
        elseif sel and btn.kind == sel.kind then
            if btn.kind == "arrow" then is_sel = (btn.dir == sel.dir)
            elseif btn.kind == "op" then is_sel = (btn.op == sel.op) end
        end

        love.graphics.setColor(0.12, 0.12, 0.20, 1)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setColor(is_sel and {0.8,0.9,1.0,1} or {0.3,0.3,0.45,1})
        love.graphics.setLineWidth(is_sel and 2 or 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(btn.label, rect.x, rect.y + 17, rect.w, "center")
    end

    love.graphics.setColor(0.5, 0.5, 0.65, 1)
    love.graphics.setFont(self.font_key)
    love.graphics.print("[R] Run", 620, PALETTE_Y + 22)
    love.graphics.print("[Spc] Step", 685, PALETTE_Y + 22)
    love.graphics.print("[Bsp] Reset", 755, PALETTE_Y + 22)

    love.graphics.setColor(0.5, 0.65, 0.5, 1)
    local nav = string.format("< [<-] Puzzle %d/%d [->] >", self.puzzle_index, PuzzleLoader.count())
    love.graphics.printf(nav, 0, PALETTE_Y + 6, HUD_X, "right")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Draw ───────────────────────────────────────────────────────────────────

function MatrixScene:draw()
    self:draw_grid()
    self:draw_travelling_matrix()
    self:draw_palette()
    self.hud:draw(self.input_matrix, self.target_matrix, nil, self.puzzle.name, self.status)
end

-- ── Input ──────────────────────────────────────────────────────────────────

function MatrixScene:_place_tile_at(cx, cy, spec)
    local width = (spec.kind == "op" and OP_WIDTHS[spec.op]) or 1

    if not self.grid:in_bounds_multi(cx, cy, width) then return end

    -- Reject if any cell in the target range is locked
    for i = 0, width - 1 do
        local t = self.grid:get(cx + i, cy)
        if t and t.locked then return end
    end

    -- Clear any existing tiles occupying those cells
    for i = 0, width - 1 do
        self.grid:clear(cx + i, cy)
    end

    local params = {}
    if DEFAULT_PARAMS[spec.op] then
        for k, v in pairs(DEFAULT_PARAMS[spec.op]) do params[k] = v end
    end
    if spec.params then
        for k, v in pairs(spec.params) do params[k] = v end
    end

    local tile = {
        kind=spec.kind, dir=spec.dir, op=spec.op,
        params=params, locked=false, width=width,
    }

    if width > 1 then
        self.grid:set_multi(cx, cy, tile, width)
    else
        self.grid:set(cx, cy, tile)
    end
end

function MatrixScene:mouse_pressed(mx, my, btn)
    -- Palette bar
    if my >= PALETTE_Y then
        for _, rect in pairs(self._btn_rects) do
            if mx >= rect.x and mx < rect.x + rect.w
            and my >= rect.y and my < rect.y + rect.h then
                local b = rect.btn
                if b.erase then
                    self.palette:select(nil)
                elseif b.kind == "arrow" then
                    self.palette:select({kind="arrow", dir=b.dir})
                elseif b.kind == "op" then
                    self.palette:select({kind="op", op=b.op})
                end
                return
            end
        end
        return
    end

    if not in_grid_panel(mx, my) then return end
    local cx, cy = screen_to_cell(mx, my)
    if not self.grid:in_bounds(cx, cy) then return end

    if btn == 2 then
        self.grid:clear(cx, cy)
        return
    end

    if btn == 1 then
        -- Clicking a param (ref) cell: adjust its parameter directly.
        local is_r, ax, ay = self.grid:is_ref(cx, cy)
        if is_r then
            local anchor_tile = self.grid:get(cx, cy)
            local param_index = cx - ax  -- 1-based
            local defs = PARAM_DEFS[anchor_tile.op]
            if defs and defs[param_index] then
                local def = defs[param_index]
                local cell_sx, _ = cell_top_left(cx, cy)
                local rel_x = mx - cell_sx
                local delta = 0
                if rel_x < CELL_SIZE / 3 then
                    delta = -1
                elseif rel_x >= CELL_SIZE * 2 / 3 then
                    delta = 1
                end
                if delta ~= 0 then
                    local cur = anchor_tile.params[def.key] or 0
                    anchor_tile.params[def.key] =
                        math.max(def.min, math.min(def.max, cur + delta))
                end
            end
            return
        end

        -- Clicking an anchor cell or empty cell: apply palette tool
        local spec = self.palette:selected()

        if spec == nil then
            self.grid:clear(cx, cy)
        elseif spec.kind == "arrow" then
            self:_place_tile_at(cx, cy, spec)
        elseif spec.kind == "op" then
            self:_place_tile_at(cx, cy, spec)
        end
    end
end

function MatrixScene:key_pressed(key)
    if key == "r" then
        if not self.running and (self.status == nil or self.status == "fail"
                              or self.status == "loop" or self.status == "out_of_bounds") then
            self:start_run()
        end
    elseif key == "space" then
        if not self.running and (self.status == nil or self.status == "running") then
            self.anim_t = 1
            self:do_step()
            self.anim_t = 1
        end
    elseif key == "backspace" then
        self:do_reset()
    elseif key == "left" then
        self.grid:clear_all(); self:load_puzzle(self.puzzle_index - 1)
    elseif key == "right" then
        self.grid:clear_all(); self:load_puzzle(self.puzzle_index + 1)
    end
end

function MatrixScene:text_input(_) end

return MatrixScene
