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

local function cell_center(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + CELL_SIZE / 2,
           GRID_Y + (cy - 1) * CELL_SIZE + CELL_SIZE / 2
end

local function in_grid_panel(mx, my)
    return mx >= GRID_X and mx < GRID_X + 10 * CELL_SIZE
       and my >= GRID_Y and my < GRID_Y + 10 * CELL_SIZE
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Returns the layout rects for the edit widget anchored to cell (cx,cy).
-- Each entry: { kind="btn", key, delta, x, y, w, h }
local function edit_widget_rects(cx, cy, defs)
    local row_h  = 22
    local btn_w  = 18
    local val_w  = 28
    local lbl_w  = 30
    local pad    = 6
    local ww     = lbl_w + btn_w + val_w + btn_w + pad * 2
    local wh     = #defs * row_h + pad * 2

    local sx, sy = cell_top_left(cx, cy)
    -- prefer below the cell, clamp to grid area
    local wy = sy + CELL_SIZE + 4
    if wy + wh > GRID_Y + 10 * CELL_SIZE then
        wy = sy - wh - 4
    end
    local wx = sx + CELL_SIZE / 2 - ww / 2
    -- clamp horizontally
    wx = math.max(GRID_X, math.min(wx, GRID_X + 10 * CELL_SIZE - ww))

    local rects = { wx=wx, wy=wy, ww=ww, wh=wh }
    for i, def in ipairs(defs) do
        local ry = wy + pad + (i - 1) * row_h
        local rx = wx + pad
        rects[i] = {
            key    = def.key,
            label  = def.label,
            min    = def.min,
            max    = def.max,
            lbl    = { x=rx,            y=ry, w=lbl_w, h=row_h },
            dec    = { x=rx+lbl_w,      y=ry, w=btn_w, h=row_h },
            val    = { x=rx+lbl_w+btn_w,y=ry, w=val_w, h=row_h },
            inc    = { x=rx+lbl_w+btn_w+val_w, y=ry, w=btn_w, h=row_h },
        }
    end
    return rects
end

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
    self.editing      = nil  -- {cx, cy} of tile being edited, or nil

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
    self.editing        = nil
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
    self.editing        = nil
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

    -- Deactivate op tiles whose cells the matrix has fully left.
    for key in pairs(self.occupied_ops) do
        if not new_fp[key] then self.occupied_ops[key] = nil end
    end

    -- Collect newly entered cells (not in old footprint, not already occupied).
    local entered = {}
    for key, cell in pairs(new_fp) do
        if not old_fp[key] and not self.occupied_ops[key] then
            entered[#entered+1] = cell
        end
    end
    -- Fire in top-to-bottom, left-to-right order.
    table.sort(entered, function(a, b)
        return a.y ~= b.y and a.y < b.y or a.x < b.x
    end)

    local mat = self.current_matrix
    for _, cell in ipairs(entered) do
        local tile = self.grid:get(cell.x, cell.y)
        if tile and tile.kind == "op" then
            mat = Cursor.apply_op(tile, mat)
            self.occupied_ops[cell_key(cell.x, cell.y)] = true
        end
    end
    self.current_matrix = mat

    if status == "sink" then
        self.running = false
        self.status  = mat:equals(self.target_matrix) and "win" or "fail"
        -- Snap to final position; don't animate into the sink cell.
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

    for cy = 1, 10 do
        for cx = 1, 10 do
            local sx, sy = cell_top_left(cx, cy)
            local tile   = self.grid:get(cx, cy)

            if (cx + cy) % 2 == 0 then
                love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)

            if tile then self:draw_tile(tile, sx, sy) end
        end
    end

    -- Highlight editing cell
    if self.editing then
        local sx, sy = cell_top_left(self.editing.cx, self.editing.cy)
        love.graphics.setColor(0.4, 0.8, 1.0, 0.25)
        love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
        love.graphics.setColor(0.4, 0.8, 1.0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx+1, sy+1, CELL_SIZE-2, CELL_SIZE-2)
        love.graphics.setLineWidth(1)
        self:draw_edit_widget()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_tile(tile, sx, sy)
    local cs    = CELL_SIZE
    local mid_y = sy + cs / 2

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
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf(OP_SYMBOLS[tile.op] or "?", sx, sy + 6, cs, "center")
        -- Compact param summary below the symbol
        local p  = tile.params or {}
        local detail = ""
        if     tile.op == "scale_row"  then detail = "r"..tostring(p.row or "?").." x"..tostring(p.scalar or "?")
        elseif tile.op == "add_rows"   then detail = "r"..tostring(p.src or "?").."+r"..tostring(p.dst or "?").." x"..tostring(p.scalar or "?")
        elseif tile.op == "swap_rows"  then detail = "r"..tostring(p.row_a or "?").."/"..tostring(p.row_b or "?")
        elseif tile.op == "scalar_mul" then detail = "x"..tostring(p.scalar or "?")
        end
        if detail ~= "" then
            love.graphics.setColor(0.7, 0.55, 0.2, 1)
            love.graphics.setFont(self.font_ui)
            love.graphics.printf(detail, sx, sy + cs - 22, cs, "center")
        end
    end

    if tile.locked then
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.circle("fill", sx + cs - 8, sy + 7, 3)
        love.graphics.rectangle("fill", sx + cs - 10, sy + 7, 4, 5)
    end
end

-- Draw the in-board +/− editor widget for self.editing
function MatrixScene:draw_edit_widget()
    local e    = self.editing
    local tile = self.grid:get(e.cx, e.cy)
    if not tile then return end
    local defs = PARAM_DEFS[tile.op]
    if not defs then return end

    local wr = edit_widget_rects(e.cx, e.cy, defs)
    local p  = tile.params

    -- Background
    love.graphics.setColor(0.10, 0.12, 0.20, 0.97)
    love.graphics.rectangle("fill", wr.wx, wr.wy, wr.ww, wr.wh, 4, 4)
    love.graphics.setColor(0.4, 0.8, 1.0, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", wr.wx, wr.wy, wr.ww, wr.wh, 4, 4)
    love.graphics.setLineWidth(1)

    for _, row in ipairs(wr) do
        local val = tostring(p[row.key] or 0)

        -- Label
        love.graphics.setColor(0.6, 0.75, 1.0, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(row.label, row.lbl.x, row.lbl.y + 4, row.lbl.w, "right")

        -- [−] button
        love.graphics.setColor(0.25, 0.25, 0.4, 1)
        love.graphics.rectangle("fill", row.dec.x, row.dec.y+2, row.dec.w, row.dec.h-4, 2,2)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setFont(self.font_val)
        love.graphics.printf("-", row.dec.x, row.dec.y + 2, row.dec.w, "center")

        -- value
        love.graphics.setColor(0.95, 0.95, 1.0, 1)
        love.graphics.setFont(self.font_val)
        love.graphics.printf(val, row.val.x, row.val.y + 3, row.val.w, "center")

        -- [+] button
        love.graphics.setColor(0.25, 0.25, 0.4, 1)
        love.graphics.rectangle("fill", row.inc.x, row.inc.y+2, row.inc.w, row.inc.h-4, 2,2)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setFont(self.font_val)
        love.graphics.printf("+", row.inc.x, row.inc.y + 2, row.inc.w, "center")
    end
end

function MatrixScene:draw_travelling_matrix()
    local mat = self.current_matrix
    if not mat then return end

    local t  = self.anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local px = lerp(self.anim_from_x, self.anim_to_x, et)
    local py = lerp(self.anim_from_y, self.anim_to_y, et)

    -- Each matrix element = one board cell
    local pw = mat.cols * CELL_SIZE
    local ph = mat.rows * CELL_SIZE

    -- Anchor panel top-left to cursor cell top-left
    local bx = px
    local by = py

    -- Draw each cell of the matrix
    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local cx = bx + (c - 1) * CELL_SIZE
            local cy = by + (r - 1) * CELL_SIZE
            local v  = mat.values[r][c]

            -- Cell background
            love.graphics.setColor(0.08, 0.08, 0.16, 0.92)
            love.graphics.rectangle("fill", cx, cy, CELL_SIZE, CELL_SIZE)

            -- Golden border per cell
            love.graphics.setColor(1, 0.80, 0.15, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx+1, cy+1, CELL_SIZE-2, CELL_SIZE-2)
            love.graphics.setLineWidth(1)

            -- Value
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
    if not self.grid:in_bounds(cx, cy) then return end
    local existing = self.grid:get(cx, cy)
    if existing and existing.locked then return end
    -- Copy default params then overwrite with any spec params
    local params = {}
    if DEFAULT_PARAMS[spec.op] then
        for k, v in pairs(DEFAULT_PARAMS[spec.op]) do params[k] = v end
    end
    if spec.params then
        for k, v in pairs(spec.params) do params[k] = v end
    end
    self.grid:set(cx, cy, {
        kind=spec.kind, dir=spec.dir, op=spec.op,
        params=params, locked=false,
    })
end

-- Check if (mx,my) hits a +/- button in the edit widget; apply and return true.
function MatrixScene:_try_edit_widget_click(mx, my)
    local e = self.editing
    if not e then return false end
    local tile = self.grid:get(e.cx, e.cy)
    if not tile then return false end
    local defs = PARAM_DEFS[tile.op]
    if not defs then return false end

    local wr = edit_widget_rects(e.cx, e.cy, defs)

    -- Check if inside widget background at all
    if mx < wr.wx or mx > wr.wx + wr.ww or my < wr.wy or my > wr.wy + wr.wh then
        return false
    end

    for _, row in ipairs(wr) do
        local function in_rect(r)
            return mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
        end
        if in_rect(row.dec) then
            local cur = tile.params[row.key] or 0
            tile.params[row.key] = math.max(row.min, cur - 1)
            return true
        end
        if in_rect(row.inc) then
            local cur = tile.params[row.key] or 0
            tile.params[row.key] = math.min(row.max, cur + 1)
            return true
        end
    end
    -- Clicked inside widget but not on a button — keep editing open
    return true
end

function MatrixScene:mouse_pressed(mx, my, btn)
    -- Edit widget gets first crack
    if self.editing then
        if self:_try_edit_widget_click(mx, my) then return end
        -- Click outside widget → close editor
        self.editing = nil
    end

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
        local spec    = self.palette:selected()
        local existing = self.grid:get(cx, cy)

        if spec == nil then
            self.grid:clear(cx, cy)

        elseif spec.kind == "arrow" then
            self:_place_tile_at(cx, cy, spec)

        elseif spec.kind == "op" then
            self:_place_tile_at(cx, cy, spec)
            -- If this op has params, open the in-board editor
            if PARAM_DEFS[spec.op] then
                self.editing = {cx=cx, cy=cy}
            end
        end

        -- Also: clicking an already-placed op tile (with no tool or same tool) opens editor
        if spec == nil or (existing and existing.kind == "op" and existing.op == spec.op) then
            local t = self.grid:get(cx, cy)
            if t and t.kind == "op" and PARAM_DEFS[t.op] then
                self.editing = {cx=cx, cy=cy}
            end
        end
    end
end

function MatrixScene:key_pressed(key)
    if key == "escape" then
        if self.editing then self.editing = nil; return end
    end

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
