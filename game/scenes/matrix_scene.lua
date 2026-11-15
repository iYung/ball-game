local Scene        = require("lua/core/scene")
local Matrix       = require("game/matrix_math")
local Grid         = require("game/grid")
local Cursor       = require("game/cursor")
local Palette      = require("game/palette")
local ParamPopup   = require("game/param_popup")
local HUD          = require("game/hud")
local PuzzleLoader = require("game/puzzle_loader")

local MatrixScene = {}
MatrixScene.__index = MatrixScene

-- Layout constants
local GRID_X     = 95   -- left margin so 10*63 = 630 is centered in 820px panel
local GRID_Y     = 20
local CELL_SIZE  = 63
local PALETTE_Y  = 660
local HUD_X      = 820

-- Ops that require a param popup before placement
local NEEDS_PARAMS = { scale_row=true, add_rows=true, swap_rows=true, scalar_mul=true }

-- Display labels for op tiles
local OP_SYMBOLS = {
    transpose  = "T",
    scale_row  = "xRn",
    add_rows   = "R+R",
    swap_rows  = "<>R",
    negate     = "-I",
    scalar_mul = "xk",
}

local DIR_ARROWS = { right="->", left="<-", up="^", down="v" }

-- Palette button definitions
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

local function cell_center(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + CELL_SIZE / 2,
           GRID_Y + (cy - 1) * CELL_SIZE + CELL_SIZE / 2
end

local function cell_to_screen(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE, GRID_Y + (cy - 1) * CELL_SIZE
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
    self.popup        = ParamPopup.new()
    self.hud          = HUD.new(HUD_X, 0, 460, 720)
    self.font_cell    = love.graphics.newFont(14)
    self.font_ui      = love.graphics.newFont(12)
    self.font_key     = love.graphics.newFont(11)
    self.pending_spec = nil   -- spec waiting for params before placement
    self.run_speed    = 0.22  -- seconds per step (animation duration)
    -- Visual position of the travelling matrix panel (screen pixels, cell center)
    self.anim_from_x  = 0
    self.anim_from_y  = 0
    self.anim_to_x    = 0
    self.anim_to_y    = 0
    self.anim_t       = 1    -- 1 = at destination, not animating
    self.anim_ready   = false -- true when anim finished and next step should fire

    -- Compute palette button positions once
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
    -- base clears drawer (unused here, but call it anyway)
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

    -- Locked tiles from puzzle definition
    if p.locked then
        for _, t in ipairs(p.locked) do
            self.grid:set(t.x, t.y, {
                kind   = t.kind,
                dir    = t.dir,
                op     = t.op,
                params = t.params or {},
                locked = true,
            })
        end
    end

    -- Source and sink (always locked)
    self.grid:set(p.source.x, p.source.y, { kind="source", dir=p.source.dir, locked=true })
    self.grid:set(p.sink.x,   p.sink.y,   { kind="sink",   locked=true })
end

function MatrixScene:do_reset()
    self.current_matrix = nil
    self.status         = nil
    self.running        = false
    self.cursor         = nil
    self.anim_t         = 1
    self.anim_ready     = false
end

function MatrixScene:_snap_anim_to_cursor()
    if self.cursor then
        local px, py = cell_center(self.cursor.x, self.cursor.y)
        self.anim_from_x = px; self.anim_from_y = py
        self.anim_to_x   = px; self.anim_to_y   = py
        self.anim_t      = 1
    end
end

function MatrixScene:start_run()
    local p             = self.puzzle
    self.current_matrix = self.input_matrix:copy()
    self.cursor         = Cursor.new(self.grid, p.source.x, p.source.y, p.source.dir,
                                     p.sink.x, p.sink.y)
    self.status         = "running"
    self.running        = true
    self.anim_t         = 1
    self.anim_ready     = true  -- fire first step immediately
    self:_snap_anim_to_cursor()
end

function MatrixScene:do_step()
    if not self.cursor then
        self:start_run()
        return
    end
    local from_x, from_y = cell_center(self.cursor.x, self.cursor.y)
    local st, new_mat    = self.cursor:step(self.current_matrix)
    self.current_matrix  = new_mat
    local to_x, to_y     = cell_center(self.cursor.x, self.cursor.y)

    -- Kick off animation from old position to new
    self.anim_from_x = from_x; self.anim_from_y = from_y
    self.anim_to_x   = to_x;   self.anim_to_y   = to_y
    self.anim_t      = 0
    self.anim_ready  = false

    if st == "sink" then
        self.running = false
        if new_mat:equals(self.target_matrix) then
            self.status = "win"
        else
            self.status = "fail"
        end
    elseif st ~= "ok" then
        self.running = false
        self.status  = st
    end
end

-- ── Update ─────────────────────────────────────────────────────────────────

function MatrixScene:update(dt)
    -- Advance animation
    if self.anim_t < 1 then
        self.anim_t = math.min(1, self.anim_t + dt / self.run_speed)
        if self.anim_t >= 1 and self.running then
            self.anim_ready = true
        end
    end
    -- Fire next step once animation completes
    if self.running and self.anim_ready then
        self.anim_ready = false
        self:do_step()
    end
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

local function set_color(t) love.graphics.setColor(t[1], t[2], t[3], t[4] or 1) end

function MatrixScene:draw_grid()
    -- Background for grid panel
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, PALETTE_Y)

    for cy = 1, 10 do
        for cx = 1, 10 do
            local sx, sy = cell_to_screen(cx, cy)
            local tile   = self.grid:get(cx, cy)

            -- Checkerboard background
            if (cx + cy) % 2 == 0 then
                love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)

            -- Cell border
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)

            if tile then
                self:draw_tile(tile, sx, sy)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_tile(tile, sx, sy)
    local cs = CELL_SIZE
    local mid_x = sx + cs / 2
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
        local sym = DIR_ARROWS[tile.dir] or "?"
        love.graphics.printf(sym, sx, mid_y - 7, cs, "center")

    elseif tile.kind == "op" then
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setFont(self.font_cell)
        local sym = OP_SYMBOLS[tile.op] or tile.op or "?"
        love.graphics.printf(sym, sx, mid_y - 12, cs, "center")
        -- Small param summary
        local p = tile.params or {}
        local detail = ""
        if tile.op == "scale_row"  then detail = "r"..tostring(p.row or "?").."x"..tostring(p.scalar or "?")
        elseif tile.op == "add_rows"   then detail = "r"..tostring(p.src or "?").."->"..tostring(p.dst or "?")
        elseif tile.op == "swap_rows"  then detail = "r"..tostring(p.row_a or "?").."/"..tostring(p.row_b or "?")
        elseif tile.op == "scalar_mul" then detail = "x"..tostring(p.scalar or "?")
        end
        if detail ~= "" then
            love.graphics.setColor(0.7, 0.55, 0.2, 1)
            love.graphics.setFont(self.font_ui)
            love.graphics.printf(detail, sx, mid_y + 4, cs, "center")
        end
    end

    -- Lock badge (small dot + line in top-right)
    if tile.locked then
        local lx = sx + cs - 10
        local ly = sy + 4
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.circle("fill", lx, ly + 4, 3)
        love.graphics.rectangle("fill", lx - 2, ly + 4, 4, 5)
    end
end

function MatrixScene:draw_travelling_matrix()
    local mat = self.current_matrix
    if not mat then return end

    -- Interpolated pixel position
    local t  = self.anim_t
    -- ease: smooth-step so it feels snappy not robotic
    local et = t * t * (3 - 2 * t)
    local px = lerp(self.anim_from_x, self.anim_to_x, et)
    local py = lerp(self.anim_from_y, self.anim_to_y, et)

    local n       = math.max(mat.rows, mat.cols)
    local cell_px = math.min(18, math.floor(60 / n))  -- px per matrix cell
    local pad     = 5
    local pw      = mat.cols * cell_px + pad * 2
    local ph      = mat.rows * cell_px + pad * 2

    -- Centre panel on px,py
    local bx = px - pw / 2
    local by = py - ph / 2

    -- Panel background + border
    love.graphics.setColor(0.08, 0.08, 0.14, 0.93)
    love.graphics.rectangle("fill", bx, by, pw, ph, 3, 3)
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, pw, ph, 3, 3)
    love.graphics.setLineWidth(1)

    -- Matrix values
    local num_font = self.font_cell
    love.graphics.setFont(num_font)
    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local v  = mat.values[r][c]
            local vx = bx + pad + (c - 1) * cell_px
            local vy = by + pad + (r - 1) * cell_px
            local s
            if v == math.floor(v) then
                s = tostring(math.floor(v))
            else
                s = string.format("%.1f", v)
            end
            love.graphics.setColor(0.95, 0.95, 1.0, 1)
            love.graphics.printf(s, vx, vy + cell_px * 0.15, cell_px, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_palette()
    -- Bar background
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, PALETTE_Y, HUD_X, 60)

    local sel = self.palette:selected()

    for _, rect in pairs(self._btn_rects) do
        local btn = rect.btn
        local is_sel = false
        if sel == nil and btn.erase then
            is_sel = true
        elseif sel and btn.kind == sel.kind then
            if btn.kind == "arrow" then
                is_sel = (btn.dir == sel.dir)
            elseif btn.kind == "op" then
                is_sel = (btn.op == sel.op)
            end
        end

        love.graphics.setColor(0.12, 0.12, 0.20, 1)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
        if is_sel then
            love.graphics.setColor(0.8, 0.9, 1.0, 1)
        else
            love.graphics.setColor(0.3, 0.3, 0.45, 1)
        end
        love.graphics.setLineWidth(is_sel and 2 or 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(btn.label, rect.x, rect.y + 17, rect.w, "center")
    end

    -- Control buttons on the right side
    local controls = {
        { label="[R] Run",   x=620, key="r" },
        { label="[Spc] Step",x=680, key="space" },
        { label="[Bsp] Reset",x=745, key="backspace" },
    }
    for _, c in ipairs(controls) do
        love.graphics.setColor(0.5, 0.5, 0.65, 1)
        love.graphics.setFont(self.font_key)
        love.graphics.print(c.label, c.x, PALETTE_Y + 22)
    end

    -- Puzzle nav
    love.graphics.setColor(0.5, 0.65, 0.5, 1)
    love.graphics.setFont(self.font_key)
    local nav = string.format("< [<-] Puzzle %d/%d [->] >", self.puzzle_index, PuzzleLoader.count())
    love.graphics.printf(nav, 0, PALETTE_Y + 6, HUD_X, "right")

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Draw ───────────────────────────────────────────────────────────────────

function MatrixScene:draw()
    self:draw_grid()
    self:draw_travelling_matrix()
    self:draw_palette()
    self.hud:draw(self.input_matrix, self.target_matrix, nil,
                  self.puzzle.name, self.status)
    self.popup:draw()
end

-- ── Input ──────────────────────────────────────────────────────────────────

function MatrixScene:_place_tile_at(cx, cy, spec)
    if not self.grid:in_bounds(cx, cy) then return end
    local existing = self.grid:get(cx, cy)
    if existing and existing.locked then return end
    local tile = {
        kind   = spec.kind,
        dir    = spec.dir,
        op     = spec.op,
        params = spec.params or {},
        locked = false,
    }
    self.grid:set(cx, cy, tile)
end

function MatrixScene:mouse_pressed(mx, my, btn)
    if self.popup:is_open() then return end

    -- Check palette bar
    if my >= PALETTE_Y then
        for _, rect in pairs(self._btn_rects) do
            if mx >= rect.x and mx < rect.x + rect.w
            and my >= rect.y and my < rect.y + rect.h then
                local b = rect.btn
                if b.erase then
                    self.palette:select(nil)
                elseif b.kind == "arrow" then
                    self.palette:select({ kind="arrow", dir=b.dir })
                elseif b.kind == "op" then
                    local spec = { kind="op", op=b.op }
                    if NEEDS_PARAMS[b.op] then
                        -- Select the op in palette and remember we need params on next placement
                        self.palette:select(spec)
                    else
                        self.palette:select(spec)
                    end
                end
                return
            end
        end
        return
    end

    -- Check grid panel
    if not in_grid_panel(mx, my) then return end
    local cx, cy = screen_to_cell(mx, my)
    if not self.grid:in_bounds(cx, cy) then return end

    if btn == 2 then
        -- Right-click: erase
        self.grid:clear(cx, cy)
        return
    end

    if btn == 1 then
        local spec = self.palette:selected()
        if spec == nil then
            -- Eraser
            self.grid:clear(cx, cy)
        elseif spec.kind == "arrow" then
            self:_place_tile_at(cx, cy, spec)
        elseif spec.kind == "op" then
            if NEEDS_PARAMS[spec.op] then
                -- Open popup; on confirm place tile at (cx, cy)
                local existing = self.grid:get(cx, cy)
                local cur_params = (existing and existing.op == spec.op) and existing.params or nil
                self.popup:open(spec.op, cur_params, function(params)
                    local full_spec = { kind="op", op=spec.op, params=params }
                    self:_place_tile_at(cx, cy, full_spec)
                end)
            else
                self:_place_tile_at(cx, cy, spec)
            end
        end
    end
end

function MatrixScene:key_pressed(key)
    if self.popup:is_open() then
        self.popup:key_pressed(key)
        return
    end

    if key == "r" then
        if not self.running and (self.status == nil or self.status == "fail"
                              or self.status == "loop" or self.status == "out_of_bounds") then
            self:start_run()
        end
    elseif key == "space" then
        if not self.running and (self.status == nil or self.status == "running") then
            -- snap any in-progress animation before stepping
            self.anim_t = 1
            self:do_step()
            -- for single-step, complete animation instantly
            self.anim_t = 1
        end
    elseif key == "backspace" then
        self:do_reset()
    elseif key == "left" then
        self.grid:clear_all()
        self:load_puzzle(self.puzzle_index - 1)
    elseif key == "right" then
        self.grid:clear_all()
        self:load_puzzle(self.puzzle_index + 1)
    end
end

function MatrixScene:text_input(text)
    self.popup:text_input(text)
end

return MatrixScene
